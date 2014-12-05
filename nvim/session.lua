require('coxpcall')


local Session = {}
Session.__index = Session


local function resume(co, ...)
  local status, result = coroutine.resume(co, ...)

  if coroutine.status(co) == 'dead' then
    if not status then
      error(result)
    end
    return
  end

  assert(coroutine.status(co) == 'suspended')
  result(co)
end

local function coroutine_exec(func, ...)
  local args = {...}
  local on_complete

  if #args > 0 and type(args[#args]) == 'function' then
    -- completion callback
    on_complete = table.remove(args)
  end

  resume(coroutine.create(function()
    local status, result = copcall(func, unpack(args))
    if on_complete then
      coroutine.yield(function()
        -- run the completion callback on the main thread
        on_complete(status, result)
      end)
    end
  end))
end

function Session.new(async_session)
  return setmetatable({
    _async_session = async_session,
    _pending_messages = {},
    _is_running = false
  }, Session)
end

function Session:next_message(timeout)
  local function on_request(method, args, response)
    table.insert(self._pending_messages, {'request', method, args, response})
    self._async_session:stop()
  end

  local function on_notification(method, args)
    table.insert(self._pending_messages, {'notification', method, args})
    self._async_session:stop()
  end

  if self._is_running then
    error('Event loop already running')
  end

  if #self._pending_messages > 0 then
    return table.remove(self._pending_messages, 1)
  end

  self._async_session:run(on_request, on_notification, timeout)
  return table.remove(self._pending_messages, 1)
end

function Session:request(method, ...)
  local args = {...}
  local err, result
  if self._is_running then
    err, result = self:_yielding_request(method, args)
  else
    err, result = self:_blocking_request(method, args)
  end

  if err then
    return false, err
  end

  return true, result
end

function Session:run(request_cb, notification_cb, setup_cb, timeout)
  local function on_request(method, args, response)
    coroutine_exec(request_cb, method, args, function(status, result)
      if status then
        response:send(result)
      else
        response:send(result, true)
      end
    end)
  end

  local function on_notification(method, args)
    coroutine_exec(notification_cb, method, args)
  end

  self._is_running = true

  if setup_cb then
    coroutine_exec(setup_cb)
  end

  while #self._pending_messages > 0 do
    local msg = table.remove(self._pending_messages, 1)
    if msg[1] == 'request' then
      on_request(msg[2], msg[3], msg[4])
    else
      on_notification(msg[2], msg[3])
    end
  end

  self._async_session:run(on_request, on_notification, timeout)
  self._is_running = false
end

function Session:stop()
  self._async_session:stop()
end

function Session:exit()
  self._async_session:exit()
end

function Session:_yielding_request(method, args)
  return coroutine.yield(function(co)
    self._async_session:request(method, args, function(err, result)
      resume(co, err, result)
    end)
  end)
end

function Session:_blocking_request(method, args)
  local err, result

  local function on_request(method, args, response)
    table.insert(self._pending_messages, {'request', method, args, response})
  end

  local function on_notification(method, args)
    table.insert(self._pending_messages, {'notification', method, args})
  end

  self._async_session:request(method, args, function(e, r)
    err = e
    result = r
    self._async_session:stop()
  end)

  self._async_session:run(on_request, on_notification)
  return err, result
end


return Session
