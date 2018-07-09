local mpack = require('mpack')

-- temporary hack to be able to manipulate buffer/window/tabpage
local Buffer = {}
Buffer.__index = Buffer
function Buffer.new(id) return setmetatable({id=id}, Buffer) end
local Window = {}
Window.__index = Window
function Window.new(id) return setmetatable({id=id}, Window) end
local Tabpage = {}
Tabpage.__index = Tabpage
function Tabpage.new(id) return setmetatable({id=id}, Tabpage) end

local function hexdump(str)
  local len = string.len(str)
  local dump = ""
  local hex = ""
  local asc = ""

  for i = 1, len do
    if 1 == i % 8 then
      dump = dump .. hex .. asc .. "\n"
      hex = string.format("%04x: ", i - 1)
      asc = ""
    end

    local ord = string.byte(str, i)
    hex = hex .. string.format("%02x ", ord)
    if ord >= 32 and ord <= 126 then
      asc = asc .. string.char(ord)
    else
      asc = asc .. "."
    end
  end

  return dump .. hex .. string.rep("   ", 8 - len % 8) .. asc
end

local Response = {}
Response.__index = Response

function Response.new(msgpack_rpc_stream, request_id)
  return setmetatable({
    _msgpack_rpc_stream = msgpack_rpc_stream,
    _request_id = request_id
  }, Response)
end

function Response:send(value, is_error)
  local data = self._msgpack_rpc_stream._session:reply(self._request_id)
  if is_error then
    data = data .. self._msgpack_rpc_stream._pack(value)
    data = data .. self._msgpack_rpc_stream._pack(mpack.NIL)
  else
    data = data .. self._msgpack_rpc_stream._pack(mpack.NIL)
    data = data .. self._msgpack_rpc_stream._pack(value)
  end
  self._msgpack_rpc_stream._stream:write(data)
end

local MsgpackRpcStream = {}
MsgpackRpcStream.__index = MsgpackRpcStream

function MsgpackRpcStream.new(stream)
  return setmetatable({
    _stream = stream,
    _previous_chunk = nil,
    _pack = mpack.Packer({
      ext = {
        [Buffer] = function(o) return 0, mpack.pack(o.id) end,
        [Window] = function(o) return 1, mpack.pack(o.id) end,
        [Tabpage] = function(o) return 2, mpack.pack(o.id) end
      }
    }),
    _session = mpack.Session({
      unpack = mpack.Unpacker({
        ext = {
          [0] = function(c, s) return Buffer.new(mpack.unpack(s)) end,
          [1] = function(c, s) return Window.new(mpack.unpack(s)) end,
          [2] = function(c, s) return Tabpage.new(mpack.unpack(s)) end
        }
      })
    }),
  }, MsgpackRpcStream)
end

function MsgpackRpcStream:write(method, args, response_cb)
  local data
  if response_cb then
    assert(type(response_cb) == 'function')
    data = self._session:request(response_cb)
  else
    data = self._session:notify()
  end

  data = data ..  self._pack(method) ..  self._pack(args)
  self._stream:write(data)
end

function MsgpackRpcStream:read_start(request_cb, notification_cb, eof_cb)
  self._stream:read_start(function(data)
    if not data then
      return eof_cb()
    end
    local status, type, id_or_cb
    local pos = 1
    local len = #data
    while pos <= len do
      -- grab a copy of pos since pcall() will set it to nil on error
      local oldpos = pos
      status, type, id_or_cb, method_or_error, args_or_result, pos = pcall(
            self._session.receive, self._session, data, pos)
      if not status then
        -- write the full blob of bad data to a specific file
        local outfile = io.open('./msgpack-invalid-data', 'w')
        outfile:write(data)
        outfile:close()

        -- build a printable representation of the bad part of the string
        local printable = hexdump(data:sub(oldpos, oldpos + 8 * 10))

        print(string.format("Error deserialising msgpack data stream at pos %d:\n%s\n",
              oldpos, printable))
        print(string.format("... occurred after %s", self._previous_chunk))
        error(type)
      end
      if type == 'request' or type == 'notification' then
        self._previous_chunk = string.format('%s<%s>', type, method_or_error)
        if type == 'request' then
          request_cb(method_or_error, args_or_result, Response.new(self,
                                                                   id_or_cb))
        else
          notification_cb(method_or_error, args_or_result)
        end
      elseif type == 'response' then
        self._previous_chunk = string.format('response<%s,%s>', id_or_cb, args_or_result)
        if method_or_error == mpack.NIL then
          method_or_error = nil
        else
          args_or_result = nil
        end
        id_or_cb(method_or_error, args_or_result)
      end
    end
  end)
end

function MsgpackRpcStream:read_stop()
  self._stream:read_stop()
end

function MsgpackRpcStream:close(signal)
  self._stream:close(signal)
end

return MsgpackRpcStream
