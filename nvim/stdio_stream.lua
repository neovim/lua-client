local uv = require('luv')


local StdioStream = {}
StdioStream.__index = StdioStream

function StdioStream.open()
  local self = setmetatable({
    _in = uv.new_pipe(false),
    _out = uv.new_pipe(false)
  }, StdioStream)
  self._in:open(0)
  self._out:open(1)
  return self
end

function StdioStream:write(data)
  self._out:write(data)
end

function StdioStream:read_start(cb)
  self._in:read_start(function(err, chunk)
    if err then
      error(err)
    end
    cb(chunk)
  end)
end

function StdioStream:read_stop()
  self._in:read_stop()
end

function StdioStream:close()
  self._in:close()
  self._out:close()
end

return StdioStream
