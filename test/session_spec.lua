local Loop = require('nvim.loop')
local MsgpackStream = require('nvim.msgpack_stream')
local AsyncSession = require('nvim.async_session')
local Session = require('nvim.session')

local nvim_prog = os.getenv('NVIM_PROG') or 'nvim'

describe('Session', function()
  local loop, msgpack_stream, async_session, session, exited

  before_each(function()
    exited = false
    loop = Loop.new()
    msgpack_stream = MsgpackStream.new(loop)
    async_session = AsyncSession.new(msgpack_stream)
    session = Session.new(async_session)
    loop:spawn({nvim_prog, '-u', 'NONE', '--embed'})
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
