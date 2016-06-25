local uv = require('luv')
local native = require('nvim.native')


local ChildProcessStream = {}
ChildProcessStream.__index = ChildProcessStream

function ChildProcessStream.spawn(argv, env)
  local self = setmetatable({
    _child_stdin = uv.new_pipe(false),
    _child_stdout = uv.new_pipe(false)
  }, ChildProcessStream)
  local prog = argv[1]
  local args = {}
  for i = 2, #argv do
    args[#args + 1] = argv[i]
  end
  self._proc, self._pid = uv.spawn(prog, {
    stdio = {self._child_stdin, self._child_stdout, 2},
    args = args,
    env = env,
  }, function()
    self:close()
  end)

  if not self._proc then
    local err = self._pid
    error(err)
  end

  return self
end

function ChildProcessStream:write(data)
  self._child_stdin:write(data)
end

function ChildProcessStream:read_start(cb)
  self._child_stdout:read_start(function(err, chunk)
    if err then
      error(err)
    end
    cb(chunk)
  end)
end

function ChildProcessStream:read_stop()
  self._child_stdout:read_stop()
end

function ChildProcessStream:close(signal)
  if self._closed then
    return
  end
  self._closed = true
  self:read_stop()
  self._child_stdin:close()
  self._child_stdout:close()
  if type(signal) == 'string' then
    self._proc:kill('sig'..signal)
  end
  self._proc:close()
  uv.run('nowait')
  native.pid_wait(self._pid)
end

return ChildProcessStream
