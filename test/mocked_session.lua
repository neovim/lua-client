local table = require('nvim.table')

local MockSession = {}
MockSession.__index = MockSession

local default_functions = {
  -- returns Integer
  {
    name = 'nvim_buf_test',
    return_type = 'String',
    parameters = {{ 'Buffer', 'buffer'}}
  },
  -- returns a * 10
  {
    name = 'nvim_buf_fun1',
    return_type = 'Integer',
    parameters = { { 'Buffer', 'buffer'}, {'Integer', 'a' } }
  },
  -- returns tostring(index)
  {
    name = 'nvim_buf_fun2',
    return_type = 'String',
    parameters = { { 'Buffer', 'buffer' }, { 'Integer', 'index' } }
  },
  -- returns void
  {
    name = 'nvim_buf_fun3',
    return_type = 'void',
    parameters = { { 'Buffer', 'buffer' } }
  },
  -- returns float
  {
    name = 'nvim_buf_fun4',
    return_type = 'Float',
    parameters = { { 'Buffer', 'buffer' }}
  },
  -- returns boolean
  {
    name = 'nvim_buf_fun5',
    return_type = 'Boolean',
    parameters = { { 'Buffer', 'buffer' }}
  },
  -- returns nil
  {
    name = 'nvim_buf_fun6',
    return_type = 'Nil',
    parameters = { { 'Buffer', 'buffer' } }
  },
  -- returns Integer, but implementation returns Float
  {
    name = 'nvim_buf_fun7',
    return_type = 'Integer',
    parameters = { { 'Buffer', 'buffer' } }
  },
  -- returns Float, but implementation returns Integer
  {
    name = 'nvim_buf_fun8',
    return_type = 'Float',
    parameters = { { 'Buffer', 'buffer' } }
  },
  -- returns Window
  {
    name = 'nvim_buf_fun9',
    return_type = 'Window',
    parameters = { { 'Buffer', 'buffer' } }
  },
  -- returns string, but implementation returns nil
  {
    name = 'nvim_buf_bad_fun1',
    return_type = 'String',
    parameters = { { 'Buffer', 'buffer' } }
  },
  -- returns string, but implementation returns boolean
  {
    name = 'nvim_buf_bad_fun2',
    return_type = 'String',
    parameters = { { 'Buffer', 'buffer' } }
  },
  -- returns Integer, but implementation returns Float
  {
    name = 'nvim_buf_bad_fun3',
    return_type = 'Integer',
    parameters = { { 'Buffer', 'buffer' } }
  },
  -- returns Integer
  {
    name = 'nvim_win_test',
    return_type = 'String',
    parameters = {{ 'Window', 'window'}}
  },
  -- returns ArrayOf(Integer)
  {
    name = 'nvim_win_fun1',
    return_type = 'ArrayOf(Integer)',
    parameters = {{ 'Window', 'window'}}
  },
  -- returns Dictionary
  {
    name = 'nvim_win_fun2',
    return_type = 'Dictionary',
    parameters = {{ 'Window', 'window'}}
  },
  -- returns Tabpage
  {
    name = 'nvim_win_fun3',
    return_type = 'Tabpage',
    parameters = {{ 'Window', 'window'}}
  },
  -- returns ArrayOf(Integer) but implementation return ArrayOf(any)
  {
    name = 'nvim_win_bad_fun1',
    return_type = 'ArrayOf(Integer)',
    parameters = {{ 'Window', 'window'}}
  },
  -- returns Integer
  {
    name = 'nvim_tabpage_test',
    return_type = 'String',
    parameters = {{ 'Tabpage', 'tabpage'}}
  },
  -- returns Array
  {
    name = 'nvim_tabpage_fun1',
    return_type = 'Array',
    parameters = {{ 'Tabpage', 'tabpage'}}
  },
  -- returns Buffer
  {
    name = 'nvim_tabpage_fun2',
    return_type = 'Buffer',
    parameters = {{ 'Tabpage', 'tabpage'}}
  },
  {
    name = 'nvim_mytype_test',
    return_type = 'String',
    parameters = {{'MyType', 'my_type'}}
  }
}

local default_functions_call = {
  nvim_buf_fun1 = function(_, ...) 
    local arg = {...}
    return true, arg[2] * 10
  end,
  nvim_buf_fun2 = function(_, ...) 
    local arg = {...}
    return true, tostring(arg[2])
  end,
  nvim_buf_fun3 = function(_, _) return true, nil end,
  nvim_buf_fun4 = function(_, _) return true, 13.1416 end,
  nvim_buf_fun5 = function(_, _) return true, true end,
  nvim_buf_fun6 = function(_, _) return true, nil end,
  nvim_buf_fun7 = function(_, _) return true, 13.1416 end,
  nvim_buf_fun8 = function(_, _) return true, 13 end,
  nvim_buf_fun9 = function(_, ...) 
    local arg = {...}
    return true, arg[1] 
  end,
  nvim_buf_bad_fun1 = function(_, _) return true, nil end,
  nvim_buf_bad_fun2 = function(_, _) return true, true end,
  nvim_tabpage_fun1 = function(_, _) 
    return true, {
    1, 2, 3.1416, '1', '2', '3.1416', true
  } end,
  nvim_tabpage_fun2 = function(_, ...)
    local arg = {...}
    return true, arg[1] 
  end,
  nvim_win_fun1 = function(_, _) return true, {1,2,3,4,5,6} end,
  nvim_win_fun2 = function(_, _) return true, {
    uno = 1,
    dos = 2,
    tres = 'tres',
    cuatro = true,
  } end,
  nvim_win_fun3 = function(_, ...) 
    local arg = {...}
    return true, arg[1]
  end,
  nvim_win_bad_fun1 = function(_, _) return true, {
    1,2,3,4,5,'6'
  } end
}

local default_ext_types = {
  Buffer = { prefix = 'nvim_buf_' },
  Window = { prefix = 'nvim_win_' },
  Tabpage = { prefix = 'nvim_tabpage_' },
  MyType = { prefix = 'nvim_mytype_' }
}

function MockSession.new(data)
  local _functions_call = data.functions_call or default_functions_call
  local _functions = data.functions or default_functions
  local _ext_types = data.ext_types or default_ext_types
  local session = {
    request = function(_, method_name, ...)
      local arg = {...}
      if method_name == 'vim_get_api_info' then
        local api_info = {
          types = _ext_types,
          error_types = {
          },
          functions = _functions
        }
        return true, {666, api_info}
      elseif _functions_call[method_name] then
        return _functions_call[method_name](method_name, unpack(arg))
      else
        local args = table.table_join(arg, ',')
        return true, string.format('called %s(%s)', method_name, args)
      end
    end
  }
  return setmetatable(session, MockSession)
end

return MockSession
