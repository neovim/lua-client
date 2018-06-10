local uv = require('luv')

local SocketStream = {}
SocketStream.__index = SocketStream

function SocketStream.open(file)
  local socket = uv.new_pipe(false)
  local self = setmetatable({
    _socket = socket,
    _stream_error = nil
  }, SocketStream)
  uv.pipe_connect(socket, file, function (err)
    self._stream_error = self._stream_error or err
  end)
  return self
end

function SocketStream:write(data)
  if self._stream_error then
    error(self._stream_error)
  end
  uv.write(self._socket, data, function(err)
    if err then
      error(self._stream_error or err)
    end
  end)
end

function SocketStream:read_start(cb)
  if self._stream_error then
    error(self._stream_error)
  end
  uv.read_start(self._socket, function(err, chunk)
    if err then
      error(err)
    end
    cb(chunk)
  end)
end

function SocketStream:read_stop()
  if self._stream_error then
    error(self._stream_error)
  end
  uv.read_stop(self._socket)
end

function SocketStream:close()
  uv.close(self._socket)
end

return SocketStream
