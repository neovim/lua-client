local ChildProcessStream = require('nvim.child_process_stream')
local Session = require('nvim.session')

local nvim_prog = os.getenv('NVIM_PROG') or 'nvim'

describe('Session', function()
  local proc_stream, msgpack_stream, msgpack_rpc_stream, session, exited

  before_each(function()
    exited = false
    proc_stream = ChildProcessStream.spawn({nvim_prog, '-u', 'NONE', '--embed'})
    session = Session.new(proc_stream)
  end)

  after_each(function()
    if not exited then
      session:request('vim_command', 'qa!')
    end
  end)

  it('can make requests to nvim', function()
    assert.are.same({true, {1, 2, 3}},
      {session:request('vim_eval', '[1, 2, 3]')})
  end)

  it('can receive messages from nvim', function()
    assert.are.same({true, 1},
      {session:request('vim_eval', 'rpcnotify(1, "lua_event", 1, [1])')})
    assert.are.same({'notification', 'lua_event', {1, {1}}},
      session:next_message())
  end)

  it('can receive requests from nvim', function()
    local notified = 0

    local function on_request(method, args)
      if method == 'lua_notify' then
        assert.are.same({true, 1},
          {session:request('vim_eval', 'rpcnotify(1, "lua_event", 2, [2])')})
        assert.are.same({true, 1},
          {session:request('vim_eval', 'rpcnotify(1, "lua_event", 2, [2])')})
        return 'notified!'
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
        {session:request('vim_eval', '[2, [3]]')})
    end

    session:run(on_request, on_notification, function()
      assert.are.same({true, 'notified!'},
        {session:request('vim_eval' , 'rpcrequest(1, "lua_notify")')})
      assert.are.same({true, 'notified!'},
        {session:request('vim_eval' , 'rpcrequest(1, "lua_notify")')})
      assert.are.same({true, 'notified!'},
        {session:request('vim_eval' , 'rpcrequest(1, "lua_notify")')})
      assert.are.same({true, {'hello from lua!'}},
        {session:request('vim_eval', 'rpcrequest(1, "lua_method", 1, [1])')})
      session:stop()
    end)
    assert.are.equal(6, notified)
  end)

  it('can deal with recursive requests from nvim', function()
    local requested = 0

    local function on_request(method, args)
      assert.are.same("method", method)
      requested = requested + 1
      if requested < 10 then
        session:request('vim_eval' , 'rpcrequest(1, "method")')
      end
      return requested
    end

    session:run(on_request, nil, function()
      session:request('vim_eval' , 'rpcrequest(1, "method")')
      session:stop()
    end)
    assert.are.equal(10, requested)
  end)

  it('can receive errors from nvim', function()
    local status, result = session:request('vim_eval',
      'rpcrequest(1, "method", 1, 2')
    assert.is_false(status)
    assert.are.equal('Failed to evaluate expression', result[2])
  end)

  it('can break out of event loop with a timeout', function()
    local responded = false
    session:run(nil, nil, function()
      session:request('vim_command' , 'sleep 5')
      responded = true
    end, 50)
    assert.is_false(responded)
    session:exit()
    exited = true
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
      'test/stdio_fixture.lua'
    })
    local session = Session.new(proc_stream)
    session:notify('a', 0, 1)
    assert.are.same({'notification', 'b', {2, 3}}, session:next_message())
    session:notify('c', 4, 5)
    assert.are.same({'notification', 'd', {6, 7}}, session:next_message())
  end)
end)
