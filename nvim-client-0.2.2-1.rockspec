package = 'nvim-client'
version = '0.2.2-1'
source = {
  url = 'https://github.com/neovim/lua-client/archive/' .. version .. '.tar.gz',
  dir = 'lua-client-' .. version,
}
description = {
  summary = 'Lua client to Nvim',
  license = 'Apache',
  homepage = 'https://github.com/neovim/lua-client',
}
dependencies = {
  'lua >= 5.1',
  'mpack',
  'luv',
  'coxpcall'
}

local function make_modules()
  return {
    ['nvim.socket_stream'] = 'nvim/socket_stream.lua',
    ['nvim.tcp_stream'] = 'nvim/tcp_stream.lua',
    ['nvim.stdio_stream'] = 'nvim/stdio_stream.lua',
    ['nvim.child_process_stream'] = 'nvim/child_process_stream.lua',
    ['nvim.msgpack_rpc_stream'] = 'nvim/msgpack_rpc_stream.lua',
    ['nvim._compat'] = 'nvim/_compat.lua',
    ['nvim.session'] = 'nvim/session.lua',
    ['nvim.native'] = {
      sources = {'nvim/native.c'}
    }
  }
end

build = {
  type = 'builtin',
  modules = make_modules(),
}
