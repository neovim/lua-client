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
  'luv',
  'coxpcall'
}
external_dependencies = {
  LIBUV = {
    header = 'uv.h'
  }
}

local function make_modules()
  return {
    ['nvim.stdio_stream'] = 'nvim/stdio_stream.lua',
    ['nvim.child_process_stream'] = 'nvim/child_process_stream.lua',
    ['nvim.msgpack_stream'] = 'nvim/msgpack_stream.lua',
    ['nvim.msgpack_rpc_stream'] = 'nvim/msgpack_rpc_stream.lua',
    ['nvim.session'] = 'nvim/session.lua'
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
    freebsd = make_plat('freebsd')
  }
}
