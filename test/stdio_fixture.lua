local deps_prefix = './.deps/usr'
if os.getenv('DEPS_PREFIX') then
  deps_prefix = os.getenv('DEPS_PREFIX')
end
package.path =
     deps_prefix
  .. '/share/lua/5.1/?.lua;' .. deps_prefix .. '/share/lua/5.1/?/init.lua;'
  .. package.path
package.cpath =
     deps_prefix
  .. '/lib/lua/5.1/?.so;'
  .. package.cpath
local assert = require("luassert")

local StdioStream = require('nvim.stdio_stream')
local Session = require('nvim.session')

local stdio_stream = StdioStream.open()
local session = Session.new(stdio_stream)

assert.are.same({'notification', 'a', {0, 1}}, session:next_message())
session:notify('b', 2, 3)
assert.are.same({'notification', 'c', {4, 5}}, session:next_message())
session:notify('d', 6, 7)
