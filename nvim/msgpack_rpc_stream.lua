local Response = {}
Response.__index = Response

function Response.new(msgpack_stream, request_id)
  return setmetatable({
    _msgpack_stream = msgpack_stream,
    _request_id = request_id
  }, Response)
end

function Response:send(value, is_error)
  if is_error then
    self._msgpack_stream:write({1, self._request_id, value, nil})
  else
    self._msgpack_stream:write({1, self._request_id, nil, value})
  end
end


local MsgpackRpcStream = {}
MsgpackRpcStream.__index = MsgpackRpcStream

function MsgpackRpcStream.new(msgpack_stream)
  return setmetatable({
    _msgpack_stream = msgpack_stream,
    _next_request_id = 1,
    _pending_requests = {}
  }, MsgpackRpcStream)
end

function MsgpackRpcStream:write(method, args, response_cb)
  if response_cb then
    assert(type(response_cb) == 'function')
    -- request
    local request_id = self._next_request_id
    self._next_request_id = request_id + 1
    self._msgpack_stream:write({0, request_id, method, args})
    self._pending_requests[request_id] = response_cb
  else
    -- notification
    self._msgpack_stream:write({2, method, args})
  end
end

function MsgpackRpcStream:read_start(request_cb, notification_cb, eof_cb)
  self._msgpack_stream:read_start(function(msg)
    if not msg then
      return eof_cb()
    end
    local msg_type = msg[1]
    if msg_type == 0 then
      -- request
      --   - msg[2]: id
      --   - msg[3]: method name
      --   - msg[4]: arguments
      request_cb(msg[3], msg[4], Response.new(self._msgpack_stream, msg[2]))
    elseif msg_type == 1 then
      -- response to a previous request:
      --   - msg[2]: the id
      --   - msg[3]: error(if any)
      --   - msg[4]: result(if not errored)
      local id = msg[2]
      local handler = self._pending_requests[id]
      self._pending_requests[id] = nil
      handler(msg[3], msg[4])
    elseif msg_type == 2 then
      -- notification/event
      --   - msg[2]: event name
      --   - msg[3]: arguments
      notification_cb(msg[2], msg[3])
    else
      self._msgpack_stream:write({1, 0, 'Invalid message type', nil})
    end
  end)
end

function MsgpackRpcStream:read_stop()
  self._msgpack_stream:read_stop()
end

function MsgpackRpcStream:close()
  self._msgpack_stream:close()
end

return MsgpackRpcStream
