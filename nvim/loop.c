#define LUA_LIB
#include <assert.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#include <sys/wait.h>

#include <lua.h>
#include <lauxlib.h>
#include <uv.h>

#define META_NAME "nvim.Loop"
#define UNUSED(x) ((void)x)

typedef enum {
  TransportTypeChild
} TransportType;

typedef struct {
  lua_State *L;
  char read_buffer[0xffff];
  bool connected, reading, exited;
  int data_cb;
  const char *error;
  uv_loop_t loop;
  uv_pipe_t in, out;
  uv_prepare_t prepare;
  uv_timer_t timer;
  uint32_t timeout;
  union {
    struct {
      uv_process_t process;
      uv_process_options_t process_options;
      uv_stdio_container_t stdio[3];
    } child;
  } transport;
  TransportType transport_type;
} UV;

static void timer_cb(uv_timer_t *handle)
{
  UV *uv = handle->data;
  uv_stop(&uv->loop);
}

static void prepare_cb(uv_prepare_t *handle)
{
  UV *uv = handle->data;
  uv_timer_start(&uv->timer, timer_cb, uv->timeout, 0);
  uv_prepare_stop(handle);
}

static void walk_cb(uv_handle_t *handle, void *arg) {
  UNUSED(arg);

  if (!uv_is_closing(handle)) {
    uv_close(handle, NULL);
  }
}

static void exit_cb(uv_process_t *proc, int64_t status, int term_signal)
{
  UV *uv;
  UNUSED(status);
  UNUSED(term_signal);

  uv = proc->data;
  uv->error = "EOF";
  /* uv_stop will be called by read_cb once all data is consumed */
}

static void alloc_cb(uv_handle_t *handle, size_t suggested, uv_buf_t *buf)
{
  UV *uv;
  UNUSED(suggested);

  uv = handle->data;

  if (uv->reading) {
    buf->len = 0;
    buf->base = NULL;
    return;
  }

  buf->len = sizeof(uv->read_buffer);
  buf->base = uv->read_buffer;
  uv->reading = true;
}

static void read_cb(uv_stream_t *stream, ssize_t cnt, const uv_buf_t *buf)
{
  UV *uv;
  UNUSED(buf);

  uv = stream->data;

  if (cnt <= 0) {
    if (cnt != UV_ENOBUFS) {
      uv->error = uv_strerror((int)cnt);
      uv_read_stop(stream);
      uv_stop(&uv->loop);
    }
    return;
  }

  /* push data_cb */
  lua_rawgeti(uv->L, LUA_REGISTRYINDEX, uv->data_cb);
  /* push read buffer */
  lua_pushlstring(uv->L, uv->read_buffer, (size_t)cnt);
  /* call data_cb */
  lua_call(uv->L, 1, 0);
  /* restore reading state */
  uv->reading = false;
}

static void write_cb(uv_write_t *req, int status)
{
  UNUSED(status);

  free(req->data);
  free(req);
}

static UV *checkuv(lua_State *L) {
  return luaL_checkudata(L, 1, META_NAME);
}

static int loop_new(lua_State *L) {
  UV *uv = lua_newuserdata(L, sizeof(UV));
  uv->L = L;
  uv->error = NULL;
  uv->connected = false;
  uv->reading = false;
  uv->exited = false;
  uv->data_cb = LUA_REFNIL;
  uv->timeout = 0;
  uv_loop_init(&uv->loop);
  uv_prepare_init(&uv->loop, &uv->prepare);
  uv_timer_init(&uv->loop, &uv->timer);
  uv->prepare.data = uv;
  uv->timer.data = uv;
  luaL_getmetatable(L, META_NAME);
  lua_setmetatable(L, -2);
  return 1;
}

static int loop_exit(lua_State *L) {
  int status;
  UV *uv = checkuv(L);

  if (uv->exited || !uv->connected) {
    return 0;
  }

  uv->exited = true;

  if (uv->data_cb != LUA_REFNIL) {
    luaL_error(L, "This should only be called after stopping the loop");
  }

  if (!lua_isnone(L, 2) && uv->transport_type == TransportTypeChild) {
    uv_process_kill(&uv->transport.child.process,
        luaL_checkint(L, 2) ? SIGKILL : SIGTERM);
  }

  /* Call uv_close on every active handle */
  uv_walk(&uv->loop, walk_cb, uv);
  /* Run the event loop until all handles are successfully closed */
  while (uv_loop_close(&uv->loop)) {
    uv_run(&uv->loop, UV_RUN_DEFAULT);
  }

  if (uv->transport_type == TransportTypeChild) {
    /* Work around libuv bug that leaves defunct children:
     * https://github.com/libuv/libuv/issues/154 */
    while (!uv_process_kill(&uv->transport.child.process, 0)) {
      waitpid(uv->transport.child.process.pid, &status, WNOHANG);
    }
  }

  return 0;
}

static int loop_delete(lua_State *L) {
  return loop_exit(L);
}

static int loop_spawn(lua_State *L) {
  int status;
  size_t i, len;
  char **argv = NULL;
  const char *error = NULL;
  UV *uv;
  uv_process_t *proc;
  uv_process_options_t *opts;

  uv = checkuv(L);
  luaL_argcheck(L, !uv->connected, 1, "Loop already connected");
  luaL_checktype(L, 2, LUA_TTABLE);
  len = lua_objlen(L, -1);  /* get size of table */
  if (!len) {
    error = "`spawn` argv must have at least one string";
    goto err;
  }

  argv = calloc(len + 1, sizeof(char *));

  for (i = 1; i <= len; i++) {
    lua_pushinteger(L, (int)i);
    lua_gettable(L, -2);

    if (lua_type(L, -1) != LUA_TSTRING) {
      error = "`spawn` argv has non-string entries";
      goto err;
    }

    argv[i - 1] = (char *)lua_tostring(L, -1);
    lua_pop(L, 1);
  }

  proc = &uv->transport.child.process;
  opts = &uv->transport.child.process_options;

  proc->data = uv;
  opts->file = argv[0];
  opts->args = argv;
  opts->stdio = uv->transport.child.stdio;
  opts->stdio_count = 3;
  opts->flags = UV_PROCESS_WINDOWS_HIDE;
  opts->exit_cb = exit_cb;
  opts->cwd = NULL;
  opts->env = NULL;

  uv_pipe_init(&uv->loop, &uv->out, 0);
  uv->transport.child.stdio[0].flags = UV_CREATE_PIPE | UV_READABLE_PIPE;
  uv->transport.child.stdio[0].data.stream = (uv_stream_t *)&uv->out;
  uv->out.data = uv;

  uv_pipe_init(&uv->loop, &uv->in, 0);
  uv->transport.child.stdio[1].flags = UV_CREATE_PIPE | UV_WRITABLE_PIPE;
  uv->transport.child.stdio[1].data.stream = (uv_stream_t *)&uv->in;
  uv->in.data = uv;

  uv->transport.child.stdio[2].flags = UV_IGNORE;
  uv->transport.child.stdio[2].data.fd = 2;

  /* Spawn the process */
  if ((status = uv_spawn(&uv->loop, proc, opts))) {
    error = uv_strerror(status);
    goto err;
  }

  free(argv);
  uv->connected = true;
  uv->transport_type = TransportTypeChild;

  return 0;

err:
  free(argv);
  luaL_error(L, error);
  return 0;
}

static int loop_send(lua_State *L) {
  UV *uv;
  uv_buf_t buf;
  uv_write_t *req;
  const char *data;
  int status;
 
  uv = checkuv(L);
  data = luaL_checklstring(L, 2, &buf.len);
  req = malloc(sizeof(uv_write_t));
  req->data = buf.base = memcpy(malloc(buf.len), data, buf.len);
  status = uv_write(req, (uv_stream_t *)&uv->out, &buf, 1, write_cb);

  if (status) {
    uv->error = uv_strerror(status);
    free(buf.base);
    free(req);
    luaL_error(L, uv->error);
  }

  return 0;
}

static int loop_run(lua_State *L) {
  UV *uv = checkuv(L);

  if (uv->exited) {
    luaL_error(L, "Loop already exited");
  }

  if (uv->data_cb != LUA_REFNIL) {
    luaL_error(L, "Loop already running");
  }

  if (uv->error) {
    luaL_error(L, uv->error);
  }

  luaL_checktype(L, 2, LUA_TFUNCTION);
  uv->timeout = 0;

  if (!lua_isnone(L, 3)) {
    int timeout = luaL_checkint(L, 3);
    if (timeout < 0) {
      luaL_error(L, "Timeout argument must be a positive integer");
    }
    uv->timeout = (uint32_t)timeout;
    uv_prepare_start(&uv->prepare, prepare_cb);
    lua_pop(L, 1);
  }

  /* Store the data callback on the registry and save the reference */
  uv->data_cb = luaL_ref(L, LUA_REGISTRYINDEX);
  uv_read_start((uv_stream_t *)&uv->in, alloc_cb, read_cb);
  uv_run(&uv->loop, UV_RUN_DEFAULT);
  uv_read_stop((uv_stream_t *)&uv->in);
  uv_prepare_stop(&uv->prepare);
  uv_timer_stop(&uv->timer);
  luaL_unref(L, LUA_REGISTRYINDEX, uv->data_cb);
  uv->data_cb = LUA_REFNIL;
  return 0;
}

static int loop_stop(lua_State *L) {
  UV *uv = checkuv(L);
  uv_stop(&uv->loop);
  return 0;
}

static int tb_panic(lua_State *L)
{
  /* same as the default panic function, but also print the lua traceback */
  const char *s = lua_tostring(L, -1);
  fputs("PANIC: unprotected error in call to Lua API (", stderr);
  fputs(s ? s : "?", stderr);
  fputc(')', stderr); fputc('\n', stderr);
  lua_getfield(L, LUA_GLOBALSINDEX, "debug");
  lua_getfield(L, -1, "traceback");
  lua_pushvalue(L, 1);
  lua_pushinteger(L, 2);
  lua_call(L, 2, 1);
  fputs(lua_tostring(L, -1), stderr);
  fflush(stderr);
  return 0;
}

static const luaL_reg looplib_m[] = {
  {"__gc", loop_delete},
  {"run", loop_run},
  {"send", loop_send},
  {"spawn", loop_spawn},
  {"stop", loop_stop},
  {"exit", loop_exit},
  {NULL, NULL}
};

static const luaL_reg looplib_f[] = {
  {"new", loop_new},
  {NULL, NULL}
};


int luaopen_nvim_loop(lua_State *L) {
  luaL_newmetatable(L, META_NAME);
  lua_pushstring(L, "__index");
  /* push the metatable */
  lua_pushvalue(L, -2);
  /* metatable.__index = metatable */
  lua_settable(L, -3);
  /* register Loop methods on the metatable */
  luaL_register(L, NULL, looplib_m);
  lua_newtable(L);
  luaL_register(L, NULL, looplib_f);
  lua_atpanic(L, tb_panic);
  return 1;
}
