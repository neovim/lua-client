package = 'nvim-client'
version = '0.0.1-10'
source = {
  url = 'git://github.com/neovim/lua-client',
  tag = '0.0.1-10'
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

-- based on:
-- https://github.com/diegonehab/luasocket/blob/master/luasocket-scm-0.rockspec
local function make_plat(plat)
  local libs = {'uv', 'pthread'}

  if plat == 'freebsd' then
    libs[#libs + 1] = 'kvm'
  end

  if plat == 'linux' then
    libs[#libs + 1] = 'rt'
    libs[#libs + 1] = 'dl'
  end

  local modules = {
    ['nvim.msgpack_stream'] = 'nvim/msgpack_stream.lua',
    ['nvim.async_session'] = 'nvim/async_session.lua',
    ['nvim.session'] = 'nvim/session.lua',
    ['nvim.loop'] = {
      sources = {'nvim/loop.c'},
      libraries = libs,
      incdirs = {"$(LIBUV_INCDIR)"},
      libdirs = {"$(LIBUV_LIBDIR)"}
    }
  }

  return {modules = modules}
end

build = {
  type = 'builtin',
  platforms = {
    linux = make_plat('linux'),
    macosx = make_plat('macosx'),
    freebsd = make_plat('freebsd')
  }
}
