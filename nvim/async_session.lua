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
    self._msgpack_stream:send({1, self._request_id, value, nil})
  else
    self._msgpack_stream:send({1, self._request_id, nil, value})
  end
end


local AsyncSession = {}
AsyncSession.__index = AsyncSession

function AsyncSession.new(msgpack_stream)
  return setmetatable({
    _msgpack_stream = msgpack_stream,
    _next_request_id = 1,
    _pending_requests = {}
  }, AsyncSession)
end

function AsyncSession:request(method, args, response_cb)
  local request_id = self._next_request_id
  self._next_request_id = request_id + 1
  self._msgpack_stream:send({0, request_id, method, args})
  self._pending_requests[request_id] = response_cb
end

function AsyncSession:run(request_cb, notification_cb)
  self._msgpack_stream:run(function(msg)
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
      self._msgpack_stream:send({1, 0, 'Invalid message type', nil})
    end
  end)
end

function AsyncSession:stop()
  self._msgpack_stream:stop()
end


return AsyncSession
