package = 'nvim-client'
version = '0.0.1-1'
source = {
  url = 'git://github.com/neovim/lua-client',
  tag = '0.0.1-1'
}
description = {
  summary = "Lua client to Nvim",
  license = 'Apache'
}
dependencies = {
  'lua ~> 5.1',
  'lua-messagepack',
  'coxpcall'
}
external_dependencies = {
  LIBUV = {
    header = "uv.h"
  }
}
build = {
  type = 'builtin',
  modules = {
    ['nvim.msgpack_stream'] = 'nvim/msgpack_stream.lua',
    ['nvim.async_session'] = 'nvim/async_session.lua',
    ['nvim.session'] = 'nvim/session.lua',
    ['nvim.loop'] = {
      sources = {'nvim/loop.c'},
      libraries = {'uv', 'rt', 'pthread', 'nsl', 'dl'},
      incdirs = {"$(LIBUV_INCDIR)"},
      libdirs = {"$(LIBUV_LIBDIR)"}
    }
  }
}
