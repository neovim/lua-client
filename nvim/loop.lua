local uv = require('luv')


local Loop = {}
Loop.__index = Loop

function Loop.new()
  return setmetatable({
    _out = uv.new_pipe(false),
    _in = uv.new_pipe(false),
    _prepare = uv.new_prepare(),
    _timer = uv.new_timer()
  }, Loop)
end

function Loop:spawn(argv)
  if self._connected then
    error('Loop already connected')
  end
  local prog = argv[1]
  if not prog then
    error('`spawn` argv must have at least one string')
  end
  local args = {}
  for i = 2, #argv do
    args[#args + 1] = argv[i]
  end
  self._proc, self._pid = uv.spawn(prog, {
    stdio = {self._out, self._in, nil},
    args = args,
  }, function()
    self._error = 'EOF'
  end)
  self._connected = true
end

function Loop:stdio()
  if self._connected then
    error('Loop already connected')
  end
  self._in:open(0)
  self._out:open(1)
  self._connected = true
end

function Loop:run(cb, timeout)
  if self._exited then
    error('Loop already exited')
  end

  if self._running then
    error('Loop already running')
  end

  if self._error then
    error(self._error)
  end

  if timeout then
    self._prepare:start(function()
      self._timer:start(timeout, 0, function()
        uv.stop()
      end)
      self._prepare:stop()
    end)
  end

  self._in:read_start(function(err, chunk)
    if err then
      self._error = err
    elseif not chunk then
      self._error = 'EOF'
    else
      cb(chunk)
    end

    if self._error then
      self._in:read_stop()
      uv.stop()
    end
  end)

  self._running = true
  uv.run()
  self._running = false
  self._prepare:stop()
  self._timer:stop()
end

function Loop:send(data)
  self._out:write(data)
end

function Loop:stop()
  uv.stop()
end

function Loop:exit(kill)
  if self._running then
    error('This should only be called after stopping the loop')
  end

  if self._exited or not self._connected then
    return
  end

  self._exited = true

  if self._proc then
    if kill then
      self._proc:kill('KILL')
    else
      self._proc:kill()
    end
  end

  uv.walk(function(handle)
    if not handle:is_closing() then
      handle:close()
    end
  end)
end

return Loop
