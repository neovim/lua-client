------------
-- Nvim
-- Implements a nvim client
-- module: Nvim

local Api = require 'nvim.api'
local Session = require 'nvim.session'
local SocketStream = require 'nvim.socket_stream'
local TcpStream = require 'nvim.tcp_stream'
local ChildProcessStream = require 'nvim.child_process_stream'

local LATEST_NVIM_API_VERSION = 1
local NVIM_API_VERSION = LATEST_NVIM_API_VERSION

local Nvim = {}
Nvim.__index = Nvim

--- Creates a new Nvim client using an existing session
-- Session: session
-- ?number: api_version version of nvim to use
-- treturn: Nvim
function Nvim.new_from_session(session, api_version)
  local _api_version = api_version or NVIM_API_VERSION
  if _api_version > LATEST_NVIM_API_VERSION then
    return nil, 'Invalid api_version ' .. _api_version .. '. Latest api version is ' .. LATEST_NVIM_API_VERSION
  end
  return Api.new(session, _api_version)
end

function Nvim.new_from_socket_file(socket_file, api_version)
  return Nvim.new_from_session(Session.new(SocketStream.open(socket_file)), api_version)
end

function Nvim.new_from_socket(host, port, api_version)
  return Nvim.new_from_session(Session.new(TcpStream.open(host, port)), api_version)
end

function Nvim.new_from_stream(stream, api_version)
  return Nvim.new_from_session(Session.new(stream), api_version)
end

function Nvim.new_from_process(api_version)
  local Nvim_prog = os.getenv('NVIM_PROG') or 'nvim'
  return Nvim.new_from_session(Session.new(ChildProcessStream.spawn({
    Nvim_prog, '-u', 'NONE', '--embed'  
  })), api_version)
end

return Nvim
