lua-client
==========

[![Build Status](https://travis-ci.org/neovim/lua-client.svg?branch=master)](https://travis-ci.org/neovim/lua-client)

Lua client for Neovim

Build
-----

The `Makefile` pulls and builds various dependencies into `.deps`.

     make

Test
----

Run tests against whatever `nvim` is in `$PATH`:

     make test

Use a specific `nvim`:

     NVIM_PROG=/path/to/nvim make test

Use test tags (`it('#foo', function() ...`):

     NVIM_PROG=/path/to/nvim make test TEST_TAG=foo
=======

Basic usage
-----------

The module `nvim.nvim` provides a set of functions to connect to an instance of neovim.

### Create an instance of the client

First of all we need to get an instance of the client ready to talk with neovim.

#### new_from_socket_file

Connects to a running neovim instance using a socket file stream.

```lua
local Nvim = require('nvim.nvim')
local nvim = Nvim.new_from_socket_file('/tmp/.nvim.socket')
```

#### new_from_socket

Connects to a running neovim instance using a socket tcp stream.

```lua
local Nvim = require('nvim.nvim')
local nvim = Nvim.new_from_socket('127.0.0.1', 6666)
```

#### new_from_process

```lua
local Nvim = require('nvim.nvim')
local nvim = Nvim.new_from_process()
```

This code will create a new embedded neovim instance and will connect to it.


### Using the client

#### Listing the types available in the client

Once we have a client we can list the basic and extended types supported by neovim.

```lua
local Nvim = require('nvim.nvim')
local nvim = Nvim.new_from_process()

for _, m in pairs(nvim._types) do
  print(m)
end
```

The output should be something like this:

```
Buffer[nvim ext type]
Integer[nvim type]
ArrayOf[nvim type]
Window[nvim ext type]
Dictionary[nvim type]
Object[nvim type]
Nil[nvim type]
Tabpage[nvim ext type]
Float[nvim type]
void[nvim type]
Array[nvim type]
Boolean[nvim type]
String[nvim type]
```

##### Basic types vs extended types

Basic types are coerced to lua types directly whereas extended types implement their respective class (Tabpage, Window and Buffer in the example). This means that we need to use `:` to call the methods of an extended type.

The client verifies the types used in the method/function before calling them.

#### Listing the functions available in the client

We can list the methods exported by neovim showing the full signature.

```lua
local nvim = Nvim.new_from_process()

for _, m in pairs(nvim.methods) do
  print(m)
end
```

This code should output something like this:

```
nvim method: Nvim:set_current_window(Window) -> void
nvim method: Nvim:get_vvar(String) -> Object
nvim method: Nvim:command(String) -> void
nvim method: Nvim:replace_termcodes(String, Boolean, Boolean, Boolean) -> String
nvim method: Nvim:get_tabpages() -> ArrayOf(Tabpage)
nvim method: Nvim:get_current_window() -> Window
nvim method: Nvim:call_function(String, Array) -> Object
nvim method: Nvim:unsubscribe(String) -> void
nvim method: Nvim:get_current_buffer() -> Buffer
nvim method: Nvim:set_option(String, Object) -> void
nvim method: Nvim:set_current_line(String) -> void
nvim method: Nvim:get_buffers() -> ArrayOf(Buffer)
nvim method: Nvim:out_write(String) -> void
nvim method: Nvim:report_error(String) -> void
nvim method: Nvim:set_current_buffer(Buffer) -> void
nvim method: Nvim:change_directory(String) -> void
nvim method: Nvim:get_api_info() -> Array
nvim method: Nvim:get_var(String) -> Object
nvim method: Nvim:get_color_map() -> Dictionary
nvim method: Nvim:strwidth(String) -> Integer
nvim method: Nvim:command_output(String) -> String
nvim method: Nvim:feedkeys(String, String, Boolean) -> void
nvim method: Nvim:get_option(String) -> Object
nvim method: Nvim:get_windows() -> ArrayOf(Window)
nvim method: Nvim:eval(String) -> Object
nvim method: Nvim:set_current_tabpage(Tabpage) -> void
nvim method: Nvim:get_current_line() -> String
nvim method: Nvim:get_current_tabpage() -> Tabpage
nvim method: Nvim:del_var(String) -> Object
nvim method: Nvim:set_var(String, Object) -> Object
nvim method: Nvim:err_write(String) -> void
nvim method: Nvim:subscribe(String) -> void
nvim method: Nvim:del_current_line() -> void
nvim method: Nvim:name_to_color(String) -> Integer
nvim method: Nvim:list_runtime_paths() -> ArrayOf(String)
nvim method: Nvim:input(String) -> Integer
```

#### Using extended types

We can also list the methods exported by a concrete extended type like this:

```lua
local Nvim = require('nvim.nvim')
local nvim = Nvim.new_from_process()

local buffer = nvim.get_current_buffer()
for _, m in pairs(buffer.methods) do
  print(m)
end
```

Output:

```
nvim method: Buffer:line_count() -> Integer
nvim method: Buffer:get_lines(Integer, Integer, Boolean) -> ArrayOf(String)
nvim method: Buffer:add_highlight(Integer, String, Integer, Integer, Integer) -> Integer
nvim method: Buffer:del_var(String) -> Object
nvim method: Buffer:get_option(String) -> Object
nvim method: Buffer:get_var(String) -> Object
nvim method: Buffer:get_line_slice(Integer, Integer, Boolean, Boolean) -> ArrayOf(String)
nvim method: Buffer:get_name() -> String
nvim method: Buffer:insert(Integer, ArrayOf(String)) -> void
nvim method: Buffer:get_line(Integer) -> String
nvim method: Buffer:get_mark(String) -> ArrayOf(Integer, 2)
nvim method: Buffer:set_name(String) -> void
nvim method: Buffer:set_lines(Integer, Integer, Boolean, ArrayOf(String)) -> void
nvim method: Buffer:is_valid() -> Boolean
nvim method: Buffer:set_var(String, Object) -> Object
nvim method: Buffer:set_line_slice(Integer, Integer, Boolean, Boolean, ArrayOf(String)) -> void
nvim method: Buffer:get_number() -> Integer
nvim method: Buffer:set_line(Integer, String) -> void
nvim method: Buffer:set_option(String, Object) -> void
nvim method: Buffer:del_line(Integer) -> void
nvim method: Buffer:clear_highlight(Integer, Integer, Integer) -> void
```

When we call a function or method that returns an extended type the client will return an instance of a class implementing that type. For example:

```lua
local Nvim = require('nvim.nvim')
local nvim = Nvim.new_from_process()

-- Print the number of lines in the current buffer
local buffer = nvim.get_current_buffer()
print(buffer:line_count()) -- should print 1
```

The same procedure can be done for other extended types provided by neovim.

### More examples

There are more examples in the integration tests `test/integration/nvim_spec.lua`
