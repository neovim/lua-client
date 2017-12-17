------------
-- Nvim
-- Implements a nvim client
-- module: Nvim

local Api = require 'nvim.api'
local Session = require 'nvim.session'
local SocketStream = require 'nvim.socket_stream'
local TcpStream = require 'nvim.tcp_stream'
local ChildProcessStream = require 'nvim.child_process_stream'

local Nvim = {}
Nvim.__index = Nvim

--- Creates a new Nvim client using an existing session
-- Session: session
-- ?number: api_version version of nvim to use
-- treturn: Nvim
function Nvim.new_from_session(session, api_level, include_deprecated)
  return Api.new(session, api_level, include_deprecated)
end

function Nvim.new_from_socket_file(socket_file, api_level, include_deprecated)
  return Nvim.new_from_session(Session.new(SocketStream.open(socket_file)), api_level,
                               include_deprecated)
end

function Nvim.new_from_socket(host, port, api_level, include_deprecated)
  return Nvim.new_from_session(Session.new(TcpStream.open(host, port)), api_level,
                               include_deprecated)
end

function Nvim.new_from_stream(stream, api_level, include_deprecated)
  return Nvim.new_from_session(Session.new(stream), api_level, include_deprecated)
end

function Nvim.new_from_process(api_level, include_deprecated)
  local Nvim_prog = os.getenv('NVIM_PROG') or 'nvim'
  return Nvim.new_from_session(Session.new(ChildProcessStream.spawn({
    Nvim_prog, '-u', 'NONE', '--embed'
  })), api_level, include_deprecated)
end

return Nvim
