--- stdio test fixture / program.
--
-- Lua's paths are passed as arguments to reflect the path in the test itself.
package.path = arg[1]
package.cpath = arg[2]
local assert = require("luassert")

local StdioStream = require('nvim.stdio_stream')
local Session = require('nvim.session')

local stdio_stream = StdioStream.open()
local session = Session.new(stdio_stream)

assert.are.same({'notification', 'a', {0, 1}}, session:next_message())
session:notify('b', 2, 3)
assert.are.same({'notification', 'c', {4, 5}}, session:next_message())
session:notify('d', 6, 7)
