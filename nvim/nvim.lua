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
-- treturn: Nvim
function Nvim.new_from_session(session)
  return Api.new(session)
end

function Nvim.new_from_socket_file(socket_file)
  return Nvim.new_from_session(Session.new(SocketStream.open(socket_file)))
end

function Nvim.new_from_socket(host, port)
  return Nvim.new_from_session(Session.new(TcpStream.open(host, port)))
end

function Nvim.new_from_stream(stream)
  return Nvim.new_from_session(Session.new(stream))
end

function Nvim.new_from_process()
  local Nvim_prog = os.getenv('NVIM_PROG') or 'nvim'
  return Nvim.new_from_session(Session.new(ChildProcessStream.spawn({
    Nvim_prog, '-u', 'NONE', '--embed'  
  })))
end

return Nvim
