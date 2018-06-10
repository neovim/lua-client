local uv = require('luv')

local TcpStream = {}
TcpStream.__index = TcpStream

function TcpStream.open(host, port)
  local client = uv.new_tcp()
  local self = setmetatable({
    _socket = client,
    _stream_error = nil
  }, TcpStream)
  uv.tcp_connect(client, host, port, function (err)
    self._stream_error = self._stream_error or err
  end)
  return self
end

function TcpStream:write(data)
  if self._stream_error then
    error(self._stream_error)
  end
  uv.write(self._socket, data, function(err)
    if err then
      error(self._stream_error or err)
    end
  end)
end

function TcpStream:read_start(cb)
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

function TcpStream:read_stop()
  if self._stream_error then
    error(self._stream_error)
  end
  uv.read_stop(self._socket)
end

function TcpStream:close()
  uv.close(self._socket)
end

return TcpStream
