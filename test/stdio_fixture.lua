local Loop = require('nvim.loop')

local loop = Loop.new()
loop:stdio()
loop:run(function(data)
  loop:send('received:'..data)
  loop:stop()
end)
loop:exit()
