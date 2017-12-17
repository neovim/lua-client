local table = require('nvim.table')

local MockSession = {}
MockSession.__index = MockSession

function MockSession.new(mocked_api_info)
  local session = {
    request = function(_, method_name, ...)
      local arg = {...}
      if method_name == 'vim_get_api_info' then
        return true, {666, mocked_api_info}
      else
        local args = table.table_join(arg, ',')
        return true, string.format('called %s(%s)', method_name, args)
      end
    end
  }
  return setmetatable(session, MockSession)
end

function MockSession.new_from_file(file)
  local f = assert(loadfile(file))
  return MockSession.new(f())
end

return MockSession
