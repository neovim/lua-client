local ChildProcessStream = require('nvim.child_process_stream')
local TcpStream = require('nvim.tcp_stream')
local SocketStream = require('nvim.socket_stream')
local Session = require('nvim.session')
local coxpcall = require('coxpcall')
local busted = require('busted')
require('nvim._compat')

local nvim_prog = os.getenv('NVIM_PROG') or 'nvim'
local child_session
local socket_session
local socket_file
local tcp_session
do
  math.randomseed(os.time())
  socket_file = string.format("/tmp/nvim.socket-%d", math.random(1000,9999))
end

local function test_session(description, session_factory, session_destroy)
  local get_api_info = function (session)
    local ok, res = session:request('nvim_get_api_info')
    return ok, unpack(res)
  end
  describe(description, function()
    local closed, session

    before_each(function()
      closed = false
      session = session_factory()
    end)

    after_each(function()
      if not closed then
        session:request('nvim_command', 'qa!')
      end
    end)

    it('can make requests to nvim', function()
      assert.are.same({true, {1, 2, 3}},
        {session:request('nvim_eval', '[1, 2, 3]')})
    end)

    it('can get api metadata', function()
      local res, channel_id, api_t = get_api_info(session)
      assert.is_true(res)
      assert.is_true(type(channel_id) == "number")
      assert.is_true(type(api_t) == "table")
      assert.is_true(type(api_t["functions"]) == "table")
      assert.is_true(type(api_t["error_types"]) == "table")
      assert.is_true(type(api_t["types"]) == "table")
    end)

    it('can receive messages from nvim', function()
      local _, channel_id, _ = get_api_info(session)
      assert.are.same({true, 1},
        {session:request('nvim_eval', string.format('rpcnotify(%d, "lua_event", 1, [1])', channel_id))})
      assert.are.same({'notification', 'lua_event', {1, {1}}},
        session:next_message())
    end)

    it('can receive requests from nvim', function()
      local notified = 0
      local _, channel_id, _ = get_api_info(session)
      local function on_request(method, args)
        if method == 'lua_notify' then
          assert.are.same({true, 1},
            {session:request('nvim_eval', string.format('rpcnotify(%d, "lua_event", 2, [2])', channel_id))})
          assert.are.same({true, 1},
            {session:request('nvim_eval', string.format('rpcnotify(%d, "lua_event", 2, [2])', channel_id))})
          return 'notified!'
        elseif method == 'lua_error' then
          return 'error message', true
        end

        assert.are.same('lua_method', method)
        assert.are.same({1, {1}}, args)
        return {'hello from lua!'}
      end

      local function on_notification(method, args)
        notified = notified + 1
        assert.are.same('lua_event', method)
        assert.are.same({2, {2}}, args)
        assert.are.same({true, {2, {3}}},
          {session:request('nvim_eval', '[2, [3]')})
      end

      local err
      session:run(on_request, on_notification, function()
        _, err = coxpcall.pcall(function()
          assert.are.same({true, 'notified!'},
            {session:request('nvim_eval' , string.format('rpcrequest(%d, "lua_notify")', channel_id))})
          assert.are.same({true, 'notified!'},
            {session:request('nvim_eval' , string.format('rpcrequest(%d, "lua_notify")', channel_id))})
          assert.are.same({true, 'notified!'},
            {session:request('nvim_eval' , string.format('rpcrequest(%d, "lua_notify")', channel_id))})
          assert.are.same({true, {'hello from lua!'}},
            {session:request('nvim_eval', string.format('rpcrequest(%d, "lua_method", 1, [1])', channel_id))})
          assert.are.same({false, {0, string.format(
              "Vim:Error invoking 'lua_error' on channel %d:\nerror message",
              channel_id)}},
            {session:request('nvim_eval', string.format('rpcrequest(%d, "lua_error")', channel_id))})
        end)
        session:stop()
      end)
      if err then
        busted.fail(err, 2)
      end
      assert.are.equal(6, notified)
    end)

    it('can deal with recursive requests from nvim', function()
      local requested = 0
      local _, channel_id, _ = get_api_info(session)

      local function on_request(method)
        assert.are.same("method", method)
        requested = requested + 1
        if requested < 10 then
          session:request('nvim_eval' , string.format('rpcrequest(%d, "method")', channel_id))
        end
        return requested
      end

      session:run(on_request, nil, function()
        session:request('nvim_eval' , string.format('rpcrequest(%d, "method")', channel_id))
        session:stop()
      end)
      assert.are.equal(10, requested)
    end)

    it('can receive errors from nvim', function()
      local _, channel_id, _ = get_api_info(session)
      local status, result = session:request('nvim_eval',
        string.format('rpcrequest(%d, "method", 1, 2', channel_id))
      assert.is_false(status)
      -- Improved parsing in nvim changed the error message between 0.2.2 and
      -- 0.3.0, but accept either to ease transition between versions
      if string.match(result[2], 'Failed') then
        assert.are.equal('Failed to evaluate expression', result[2])
      else
        assert.are.equal('Vim:E116: Invalid arguments for function rpcrequest', result[2])
      end
    end)

    it('can break out of event loop with a timeout', function()
      local responded = false
      session:run(nil, nil, function()
        session:request('nvim_command' , 'sleep 5')
        responded = true
      end, 50)
      assert.is_false(responded)
      if session_destroy then
        session_destroy()
      else
        session:close()
      end
      closed = true
    end)
  end)
end

-- Session using ChildProcessStream
test_session("Session using ChidProcessStream", function ()
  local proc_stream = ChildProcessStream.spawn({
    nvim_prog, '-u', 'NONE', '--embed',
  })
  return Session.new(proc_stream)
end)

-- Session using SocketStream
test_session(string.format("Session using SocketStream [%s]", socket_file), function ()
  child_session = Session.new(ChildProcessStream.spawn({
    nvim_prog, '-u', 'NONE', '--embed', '--headless',
    '--cmd', string.format('call serverstart("%s")', socket_file)
  }))
  child_session:request('nvim_eval', '1') -- wait for nvim to start
  local socket_stream = SocketStream.open(socket_file)
  socket_session = Session.new(socket_stream)
  return socket_session
end, function ()
  child_session:close()
  socket_session:close()
  -- clean up leftovers if something goes wrong
  local fd = io.open(socket_file)
  if fd then
    os.execute(string.format("rm %s", socket_file))
    fd:close()
  end
end)

describe('Session using SocketStream', function ()
  before_each(function()
    local socket_stream = SocketStream.open("/tmp/nvim.sock")
    socket_session = Session.new(socket_stream)
  end)

  after_each(function()
    socket_session:close()
  end)

  it('throws ENOENT error when socket does not exist', function ()
    assert.has_error(function ()
      socket_session:request('nvim_eval', '1 + 1 + 1')
    end, "ENOENT")
  end)
end)

-- Session using TcpStream
test_session("Session using TcpStream", function ()
  child_session = Session.new(ChildProcessStream.spawn({
    nvim_prog, '-u', 'NONE', '--embed', '--headless',
    '--cmd', 'call serverstart("127.0.0.1:6666")'
  }))

  child_session:request('nvim_eval', '1')  -- wait for nvim to start
  local tcp_stream = TcpStream.open("127.0.0.1", 6666)
  tcp_session = Session.new(tcp_stream)
  return tcp_session
end, function ()
  child_session:close()
  tcp_session:close()
end)

describe('Session using TcpStream', function ()
  before_each(function()
    local tcp_stream = TcpStream.open("127.0.0.1", 6666)
    tcp_session = Session.new(tcp_stream)
  end)

  after_each(function()
    tcp_session:close()
  end)

  -- TODO(justinmk): Call luv_set_callback() to fail correctly?
  -- https://github.com/luvit/luv/pull/350
  pending('(see luv issue: https://github.com/luvit/luv/pull/350 ) TCP socket throws ECONNREFUSED if Nvim is not listening', function ()
    assert.has_error(function ()
      tcp_session:request('nvim_eval', '1 + 1 + 1')
    end, "ECONNREFUSED")
  end)
end)

-- get the path to the lua interpreter, taken from
-- http://stackoverflow.com/a/18304231
local i_min = 0
while arg[ i_min ] do i_min = i_min - 1 end
i_min = i_min + 1

describe('stdio', function()
  it('sends and receive data through stdout/stdin', function()
    local proc_stream = ChildProcessStream.spawn({
      arg[i_min],
      'test/stdio_fixture.lua', package.path, package.cpath
    })
    local session = Session.new(proc_stream)
    session:notify('a', 0, 1)
    assert.are.same({'notification', 'b', {2, 3}}, session:next_message())
    session:notify('c', 4, 5)
    assert.are.same({'notification', 'd', {6, 7}}, session:next_message())
  end)
end)
