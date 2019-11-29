#define LUA_LIB
#include <lua.h>
#include <lauxlib.h>

#define UNUSED(x) ((void)x)

#ifdef _WIN32
static int pid_wait(lua_State *L) {
  (void)(L);
  return 0;
}
#else
#include <sys/wait.h>
#include <signal.h>

static int pid_wait(lua_State *L) {
  int status;
  pid_t pid = (pid_t)luaL_checkinteger(L, 1);
  /* Work around libuv bug that leaves defunct children:
   * https://github.com/libuv/libuv/issues/154 */
  while (!kill(pid, 0)) waitpid(pid, &status, WNOHANG);
  return 0;
}
#endif

static const luaL_Reg native_lib_f[] = {
  {"pid_wait", pid_wait},
  {NULL, NULL}
};

int luaopen_nvim_native(lua_State *L) {
  lua_newtable(L);
#if LUA_VERSION_NUM >= 502
  luaL_setfuncs(L, native_lib_f, 0);
#else
  luaL_register(L, NULL, native_lib_f);
#endif
  return 1;
}
