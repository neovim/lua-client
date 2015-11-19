package = 'nvim-client'
version = '0.0.1-16'
source = {
  url = 'https://github.com/tarruda/lua-client/archive/refactor-loop-to-use-luv.tar.gz',
  dir = 'lua-client-refactor-loop-to-use-luv',
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

local function make_modules()
  return {
    ['nvim.msgpack_stream'] = 'nvim/msgpack_stream.lua',
    ['nvim.async_session'] = 'nvim/async_session.lua',
    ['nvim.session'] = 'nvim/session.lua',
    ['nvim.loop'] = 'nvim/loop.lua'
  }
end

build = {
  type = 'builtin',
  modules = make_modules(),
}
