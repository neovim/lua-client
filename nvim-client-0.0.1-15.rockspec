package = 'nvim-client'
version = '0.0.1-15'
source = {
  url = 'https://github.com/neovim/lua-client/archive/' .. version .. '.tar.gz',
  dir = 'lua-client-' .. version,
}
description = {
  summary = 'Lua client to Nvim',
  license = 'Apache'
}
dependencies = {
  'lua ~> 5.1',
  'lua-messagepack',
  'coxpcall'
}
external_dependencies = {
  LIBUV = {
    header = 'uv.h'
  }
}

local function make_modules()
  return {
    ['nvim.msgpack_stream'] = 'nvim/msgpack_stream.lua',
    ['nvim.async_session'] = 'nvim/async_session.lua',
    ['nvim.session'] = 'nvim/session.lua',
    ['nvim.loop'] = {
      sources = {'nvim/loop.c'},
      libraries = {'uv'},
      incdirs = {"$(LIBUV_INCDIR)"},
      libdirs = {"$(LIBUV_LIBDIR)"}
    }
  }
end

-- based on:
-- https://github.com/diegonehab/luasocket/blob/master/luasocket-scm-0.rockspec
local function make_plat(plat)
  local modules = make_modules()
  local libs = modules['nvim.loop'].libraries

  if plat == 'freebsd' then
    libs[#libs + 1] = 'kvm'
  end

  if plat == 'linux' then
    libs[#libs + 1] = 'rt'
    libs[#libs + 1] = 'dl'
  end

  if plat == 'windows' then
    libs[#libs + 1] = 'psapi'
    libs[#libs + 1] = 'iphlpapi'
    libs[#libs + 1] = 'userenv'
    libs[#libs + 1] = 'ws2_32'
    libs[#libs + 1] = 'advapi32'
  else
    libs[#libs + 1] = 'pthread'
  end

  return { modules = modules }
end

build = {
  type = 'builtin',
  -- default (platform-agnostic) configuration
  modules = make_modules(),

  -- per-platform overrides
  -- https://github.com/keplerproject/luarocks/wiki/Platform-agnostic-external-dependencies
  platforms = {
    linux = make_plat('linux'),
    freebsd = make_plat('freebsd'),
    windows = make_plat('windows')
  }
}
