require('coxpcall')
local msgpack = require('MessagePack')


msgpack.set_array('with_hole')

msgpack.build_ext = function(tag, data)
  return {nvim_ext_type = true, tag = tag, data = data}
end

msgpack.packers['table'] = function(buffer, tbl)
  if tbl.nvim_ext_type then
    return msgpack.packers['ext'](buffer, tbl.tag, tbl.data)
  end
  return msgpack.packers['_table'](buffer, tbl)
end

-- needed to copy this from lua-MessagePack because the author refused to merge
-- the necessary patch to 'unpack':
-- https://github.com/fperrad/lua-MessagePack/pull/9
local function cursor_string(str)
  return {
    s = str,
    i = 1,
    j = #str,
    underflow = function (self)
      error "missing bytes"
    end,
  }
end

local function munpack(str)
  local cursor = cursor_string(str)
  local data = msgpack.unpackers['any'](cursor)
  return data, cursor.i
end

local MsgpackStream = {}
MsgpackStream.__index = MsgpackStream

function MsgpackStream.new(loop)
  return setmetatable({_loop = loop, _data = ''}, MsgpackStream)
end

function MsgpackStream:send(msg)
  self._loop:send(msgpack.pack(msg))
end

function MsgpackStream:run(message_cb)
  self._loop:run(function(data)
    self._data = self._data .. data
    while true do
      local ok, msg, pos = copcall(munpack, self._data)
      if not ok then
        break
      end
      self._data = self._data:sub(pos)
      message_cb(msg)
    end
  end)
end

function MsgpackStream:stop()
  self._loop:stop()
end


return MsgpackStream
