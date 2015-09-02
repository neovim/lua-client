local Loop = require('nvim.loop')
local MsgpackStream = require('nvim.msgpack_stream')
local AsyncSession = require('nvim.async_session')


describe('AsyncSession', function()
  local loop, msgpack_stream, async_session

  before_each(function()
    loop = Loop.new()
    msgpack_stream = MsgpackStream.new(loop)
    async_session = AsyncSession.new(msgpack_stream)
    loop:spawn({'.deps/nvim/nvim', '-u', 'NONE', '--embed'})
  end)

  after_each(function()
    async_session:request('vim_command', {'qa!'}, function(err, resp) end)
    async_session:run(nil, nil)
  end)

  it('can make requests to nvim', function()
    local responded = false
    async_session:request('vim_eval', {'[1, 2, 3]'}, function(err, resp)
      responded = true
      assert.are.same({1, 2, 3}, resp)
      async_session:stop()
    end)
    async_session:run(nil, nil)
    assert.is_true(responded)
  end)

  it('can receive requests from nvim', function()
    local responded = false
    async_session:request('vim_eval', {'rpcrequest(1, "lua_method", 1, [1])'}, function(err, resp)
      responded = true
      assert.are.same({'hello from lua!'}, resp)
      async_session:stop()
    end)
    async_session:run(function(method, args, response)
      assert.are.same('lua_method', method)
      assert.are.same({1, {1}}, args)
      response:send({'hello from lua!'})
    end, nil)
    assert.is_true(responded)
  end)

  it('can receive notifications from nvim', function()
    async_session:request('vim_eval', {'rpcnotify(1, "lua_event", 1, [1])'}, function(err, resp)
      assert.are.same(1, resp)
    end)
    local notified = false
    async_session:run(nil, function(event, args)
      notified = true
      assert.are.same('lua_event', event)
      assert.are.same({1, {1}}, args)
      async_session:stop()
    end)
    assert.is_true(notified)
  end)
end)
