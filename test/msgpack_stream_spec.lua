local msgpack = require('MessagePack')
local MsgpackStream = require('nvim.msgpack_stream')


describe('MsgpackStream', function()
  local tbl = {'abc', 'def', {1, 2, 3}}
  local loop, stream, unpacked

  local function message_cb(msg)
    table.insert(unpacked, msg)
  end

  before_each(function()
    loop = {input = {}, output = ''}
    stream = MsgpackStream.new(loop)
    unpacked = {}

    function loop:send(data)
      self.output = self.output .. data
    end

    function loop:run(data_cb)
      for _, data in ipairs(self.input) do
        data_cb(data)
      end
      self.input = {}
    end

    function loop:stop() end
  end)

  it('can unpack chunks of incomplete data', function()
    local packed_tbl = msgpack.pack(tbl)
    for i = 1, #packed_tbl do
      stream:run(message_cb)
      table.insert(loop.input, packed_tbl:sub(i, i))
    end
    -- nothing was parsed up to this point because we didn't call stream:run
    -- after adding the last byte
    assert.are.same({}, unpacked)
    stream:run(message_cb)
    assert.are.same({tbl}, unpacked)
    packed_tbl = packed_tbl .. packed_tbl
    -- do it again but feed two more instances of the 
    for i = 1, #packed_tbl, 2 do
      stream:run(message_cb)
      table.insert(loop.input, packed_tbl:sub(i, i + 1))
    end
    assert.are.same({tbl, tbl}, unpacked)
    stream:run(message_cb)
    assert.are.same({tbl, tbl, tbl}, unpacked)
  end)

  it('serializes tables passed to send', function()
    stream:send(tbl)
    local actual = msgpack.unpack(loop.output)
    assert.are.same(tbl, actual)
  end)
end)
