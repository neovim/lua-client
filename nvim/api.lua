local table = require "nvim.table"

-- Classes defined in this module
local Api = {}
local Method = {}
local Type = {}
local Types = {}
local Buffer = {nvim_type = true}
local Tabpage = {nvim_type = true}
local Window = {nvim_type = true}

--- Generates an error string
-- string: typ the expected type
-- any: value the actual value we got
-- treturn: string
local function error_convert(typ, value)
   return string.format('Expected %s, got `%s`(%s)', typ, tostring(value), type(value))
end

--- Returns a generic convert error string
-- string: typ the expected type
-- Type: type_of the concrete expected type
-- any: value the actual value we got
-- treturn: string
local function error_convert_generic(typ, typ_of, value)
  return string.format('Expected %s[%s] but we found `%s`(%s)', typ, tostring(typ_of), tostring(value), type(value))
end

--- Implemented Nvim Basic types
local Nil = {
  type_name = 'Nil',
  basic_type = true,
  new = function (v) 
    if type(v) == 'nil' then return nil end
    return nil, error_convert('Nil', v)
  end
}

local Void = {
  type_name = 'void',
  basic_type = true,
  new = function (_) return nil end
}

local Boolean = {
  type_name = 'Boolean',
  basic_type = true,
  new = function (v)
    if type(v) == 'boolean' then
      return v
    end
    return nil, error_convert('Boolean', v)
  end
}

local Integer = {
  type_name = 'Integer',
  basic_type = true,
  new = function (v)
    if type(v) == 'number' then
      return v
    end
    return nil, error_convert('Integer', v)
  end
}

local Float = {
  type_name = 'Float',
  basic_type = true,
  new = function (v) 
    if type(v) == 'number' then
      return v
    end
    return nil, error_convert('Float', v)
  end
}

local String = {
  type_name = 'String',
  basic_type = true,
  new = function (v) 
    if type(v) ~= 'string' then
      return nil, error_convert('String', v)
    else
      return tostring(v)
    end
  end
}

local Array = {
  type_name = 'Array',
  basic_type = true,
  new = function (array, of_type) 
    if type(array) ~= "table" then 
      return nil, error_convert('Array', array)
    end
    if of_type then
      local array_of = {}
      for i, value in ipairs(array) do
        local typed_value, _ = of_type.new(value)
        if not typed_value then 
          return nil, error_convert_generic('ArrayOf', of_type, value)
        end
        array_of[i] = typed_value
      end
      return array_of
    else
      return table.table_icopy(array)
    end
  end
}

local Dictionary = {
  type_name = 'Dictionary',
  basic_type = true,
  new = function (dictionary) 
    if type(dictionary) ~= 'table' then
      return nil, error_convert('Dictionary', dictionary)
    end
    return table.table_kvcopy(dictionary)
  end
}

local Object = {
  type_name = 'Object',
  basic_type = true,
  new = function(v) return v end,
}

--- Table to store the basic types in Nvim
local type_tables = {
  Nil = Nil,
  Boolean = Boolean,
  Integer = Integer,
  Float = Float,
  String = String,
  Array = Array,
  ArrayOf = table.table_kvcopy(Array, {
    type_generic = 'Array',
    regex = '(ArrayOf)%((%w+).*%)' -- TODO: We ignore the # of items in the type 
  }),
  void = Void, 
  Dictionary = Dictionary,
  Object = Object
}

--- Implemented Ext Nvim types
-- Unknown ext types will still be registered in the Api but
-- without a fancy wrapper around them.
local ext_types_table = {
  Buffer = Buffer,
  Window = Window,
  Tabpage = Tabpage
}

local err_types_table = {
}

--- Type Buffer
Buffer.__index = Buffer
function Buffer.new(buffer)
  if type(buffer) ~= 'table' then
    return nil, error_convert('Buffer', buffer)
  end
  return setmetatable({
    _type_name = 'Buffer',
    _value = buffer
  }, Buffer)
end

--- Type Window
Window.__index = Window
function Window.new(window)
  if type(window) ~= 'table' then
    return nil, error_convert('Window', window)
  end
  return setmetatable({
    _type_name = 'Window',
    _value = window
  }, Window)
end

--- Type Tabpage
Tabpage.__index = Tabpage
function Tabpage.new(tabpage)
  if type(tabpage) ~= 'table' then
    return nil, error_convert('Tabpage', tabpage)
  end
  return setmetatable({
    _type_name = 'Tabpage',
    _value = tabpage
  }, Tabpage)
end

--- Type class
-- This class represents a type in Nvim, it's always attached to a 
-- concrete session since types are created from a Nvim session
Type.__index = Type

--- __tostring metamethod generator for concrete instances for types
-- Type: typ the type of the instance
-- treturn: __tostring(instance) function
local function instance__tostring(typ)
  return function(instance)
    local str
    local mt = getmetatable(instance)
    local __tostring = mt.__tostring
    -- Replace temporary __tostring to avoid endless recursion
    mt.__tostring = nil
    if typ.type_generic then
      str = string.format('%s(%s): %s', tostring(typ.type_generic), 'Something', tostring(instance):gsub('table: ', ''))
    else
      str = string.format('%s: %s', tostring(typ), tostring(instance):gsub('table: ', ''))
    end
    mt.__tostring = __tostring
    return str
  end
end

--- __index metamethod generator for concrete instances for types
-- We pass the template__index into the generator so we can try first
-- the methods / fields implemented on it
--
-- Type: typ the type of the instance
-- {}: template__index table implementing possible methods for this type
-- treturn: __index(instance, k) metamethod
local function instance__index(typ, template__index)
  return function(instance, k)
    local method = typ:get_method(k)
    if template__index and type(template__index) == 'table' and template__index[k] then
      return template__index[k]
    elseif method then
      return function (...)
        -- wraps the call of an instance method
        local arg = {...}
        return typ.methods[k](instance, unpack(arg))(typ._session, typ._types)
      end
    else
      return nil
    end
  end
end

local function instance__eq(t1, t2)
  return t1._type_name == t2._type_name and
         table.table_eq(t1._value, t2._value)
end

--- Creates a new instance for type
-- Type: typ the type for the new instance
-- treturn: (any, Type, {Method, ...}, Types, Session) -> Type instance
local function instance_new(typ)
  return function(value, type_of)
    if typ._constructor then
      -- Create the new instance of typ and inject some needed deps
      local new_instance, err = typ._constructor(value, type_of)
      if type(new_instance) == 'table' and not typ.basic_type then
        new_instance.type_name = typ._type_name
        new_instance.methods = typ.methods
        new_instance._types = typ._types
        new_instance._session = typ._session
        local instance_mt = table.table_copy(getmetatable(new_instance) or {})
        return setmetatable(new_instance, {
          __tostring = instance__tostring(typ),
          __index = instance__index(typ, instance_mt.__index),
          __eq = instance__eq
        })
      else
        return new_instance, err
      end
    else
      return value
    end
  end
end

--- Creates a new Type
-- string: name Name of the new type
-- {}: type_tbl Table containing the type info
-- Session: session Session for this type
function Type.new(name, typ_tbl, methods, session, types)
  local basic_type = typ_tbl.basic_type or false
  local typ_mt = {
    __index = function (t, k)
      -- overwrite new method to create a new concrete type
      if k == "new" then
        return instance_new(t)
      elseif Type[k] then
        return Type[k]
      else
        return nil
      end
    end,
    __tostring = function (self)
      if self.basic_type then
        return string.format('%s[nvim type]', name)
      else
        return string.format('%s[nvim ext type]', name)
      end
    end
  }
  local typ = {
    _name = name,
    _types = types,
    _session = session,
    _constructor = (typ_tbl or {}).new or function(v) return v end,
    basic_type = basic_type,
    methods = methods,
    regex = typ_tbl.regex,
    type_generic = typ_tbl.type_generic
  }
  return setmetatable(typ, typ_mt)
end

function Type:get_method(method_name)
  return type(self.methods) == "table" and self.methods[method_name]
end

-- Method class
Method.__index = Method

local function validate_parameters(args, parameters, types)
  local errors = {}
  for i=1, #parameters do
    local typ, typ_of = types:get_type(parameters[i][1])
    if not typ then 
      return nil, {string.format('Unknown parameter type %s', parameters[i][1])}
    end
    local _, err = typ.new(args[i], typ_of)
    if err then 
      errors[#errors+1] = string.format('Error on parameter #%d: %s', i, err)
    end
  end
  if #errors > 0 then
    return false, errors
  end
  return true, table.table_sub(args, 1, #parameters) 
end

-- TODO: Use error types from Nvim here!!
local function convert_return_exception(exception)
  if type(exception) ~= 'table' then
    return nil
  end
  return exception[2]
end

local function convert_return_value(typ_name, value, types)
  local typ, type_of = types:get_type(typ_name)
  if not typ then
    typ = Type.new('Object', Object, {})
  end
  return typ.new(value, type_of)
end

Method.__call = function(method, _, ...)
  local arg = {...}
  return function(session, types)
    local validated, args = validate_parameters(arg, method._nvim_function.parameters, types)
    if not validated then 
      return nil, table.table_join(args, '|')
    end
    -- If method is an ext type we need to unwrap the underlaying nvim value
    local _args = table.table_fmap(args, function(i, v)
      if type(v) == 'table' then
        return i, v._value or v
      else
        return i, v
      end
    end)
    -- nvim api returns the status as first value and the result | error as second
    local success, returned_value = session:request(method._nvim_function.name, unpack(_args))
    if not success then 
      -- res contains error on failure
      return nil, convert_return_exception(returned_value)
    end
    local return_type = method._nvim_function.return_type
    if return_type ~= 'void' then
      local res, err = convert_return_value(return_type, returned_value, types)
      if not res then
        return nil, err
      end
      return res
    end
    return nil
  end
end

Method.__tostring = function(method)
  local method_params = ""
  local method_name = string.format('%s:%s', method._class, method._name)
  local param1
  local rest_params_i
  if method._uses_self then
    param1 = method._nvim_function.parameters[2]
    rest_params_i = 3
  else
    param1 = method._nvim_function.parameters[1]
    rest_params_i = 2
  end
  if param1 then
    method_params = table.table_ifoldr(param1[1], function(params, param)
      return string.format('%s, %s', params, param[1])
    end)(table.table_sub(method._nvim_function.parameters, rest_params_i))
  end
  return string.format('nvim method: %s(%s) -> %s', method_name, method_params, method._nvim_function.return_type)
end

function Method.new(nvim_function, type_name, func_name, uses_self)
  return setmetatable({
    _name = func_name,
    _class = type_name,
    _uses_self = uses_self,
    _nvim_function = nvim_function
  }, Method)
end

-- Api class
-- Generates a table with methods for a type
-- string: typ_name name of the type to generate the methods for
-- functions: {} a table with the functions available (coming from nvim)
-- {to_use:{string, ...}, to_avoid:{string, ...}}: prefixes table with list of prefixes used
-- to match functions and the list of prefixes to filter out functions.
-- boolean: uses_self true if methods generated should use self notation, false otherwise
-- ?number: version specifies minimum version to use, does not include functions/methods
-- deprecated since the specified version. If nil all functions/methods are included
-- treturn: {string:Method}
local function gen_methods(typ_name, functions, prefixes, uses_self, version)
  prefixes_to_use = table.table_fmap(prefixes.to_use or {typ_name}, function(k, prefix)
    return k, string.lower(prefix)
  end)
  prefixes_to_avoid = table.table_fmap(prefixes.to_avoid or {}, function(k, prefix)
    return k, string.lower(prefix)
  end)
  -- require version 0 by default
  local required_version = version or 0
  local match_prefix = function(name, prefixes)
    return table.table_any(prefixes, function(prefix)
      return name:match(prefix)
    end)
  end
  return table.table_fmap(functions, function(_, func)
    -- Filter only functions starting with prefix_name as methods
    -- Also replace prefix
    local deprecated_since = func.deprecated_since or (required_version + 1)
    local func_prefix = match_prefix(func.name, prefixes_to_use)
    if func_prefix and not match_prefix(func.name, prefixes_to_avoid) and required_version < deprecated_since then 
      local func_name = func.name:gsub(func_prefix, '')
      return func_name, Method.new(table.table_copy(func), typ_name, func_name, uses_self)
    else
      return nil
    end
  end)
end

-- Types class
Types.__index = Types

function Types:get_type(typ_name)
  for typ_exp, typ in pairs(self) do
    -- TODO: We ignore the # of items in the type (ArrayOf(String, 2))
    local matched, typ_of = string.match(typ_name, '^' .. (typ.regex or typ_exp) .. '$')
    if matched and typ_of then
      -- TODO: check if type_of does not exist
      return self:get_type(typ.type_generic), self:get_type(typ_of)
    elseif matched then
      return typ
    end
  end
  return nil
end

-- Returns a new instance of (nvim) Types
-- {} from_types types to generate
-- {} functions functions information coming from nvim api info
-- Session session session used by the client
-- number: version specifies minimum version to use, does not include functions/methods
-- deprecated since the specified version. If nil all functions/methods are included
-- treturn: Types
function Types.new(from_types, functions, session, version)
  local types_f = table.table_fmap(from_types, function(typ_name, typ_tbl)
    local methods = {}
    if not typ_tbl.basic_type then
      prefixes = { to_use = {typ_tbl.prefix or typ_name } }
      methods = gen_methods(typ_name, functions, prefixes, not typ_tbl.basic_type, version)
    end
    return typ_name, function(types)
      return Type.new(typ_name, typ_tbl, methods, session, types)
    end
  end)
  local _types = {}
  for k, f in pairs(types_f) do
    _types[k] = f(_types) -- ugly recursion
  end

  return setmetatable(_types, Types)
end

function Api:get_type(typ_name)
  return self._types:get_type(typ_name)
end

function Api:get_method(method)
  return self.methods[method]
end

Api.__index = function(api, k)
  if Api[k] then return Api[k] end
  local method = api:get_method(k)
  if method then
    -- TODO: This code is a repetition of instance__index, generalize it!
    return function(...)
      local arg = {...}
      return api.methods[k](api, unpack(arg))(api._session, api._types)
    end
  else
    return nil
  end
end

Api.__tostring = function(api)
  local mt = getmetatable(api)
  local __tostring = mt.__tostring
  mt.__tostring = nil
  local str = string.format('nvim: %s', tostring(api))
  mt.__tostring = __tostring
  return str
end

--- Returns an instance of (Nvim) Api
-- Session: session used by the client
-- ?number: version specifies minimum version to use, does not include functions/methods
-- deprecated since the specified version. If nil all functions/methods are included
-- treturn: Api
function Api.new(session, version)
  local ok, res = session:request('vim_get_api_info')
  local _, api_info
  if ok then
    _, api_info = unpack(res)
  else
    return nil, 'Error getting api info'
  end

  local ext_types = table.table_fmap(api_info.types, function(typ_name, typ_info)
    local typ_tbl = ext_types_table[typ_name]
    return typ_name, table.table_concat(typ_tbl or {}, typ_info)
  end)

  local ext_types_prefixes = table.table_fmap(ext_types, function(typ_name, typ_info)
    return nil, typ_info.prefix or typ_name
  end)

  local all_types = table.table_concat(ext_types, table.table_copy(type_tables))

  local _error_types = table.table_fmap(api_info.error_types, function(typ_name)
    local typ_tbl = err_types_table[typ_name]
    return typ_name, typ_tbl or {}
  end)
  local types = Types.new(all_types, api_info.functions, session, version or 0)
  local error_types = Types.new(_error_types, api_info.functions, session, version or 0)

  local prefixes = {
    to_use = {'nvim_', 'vim_'},
    to_avoid = ext_types_prefixes
  }
  local api = setmetatable({
    _api_info = api_info,
    _session = session,
    _types = types,
    _error_types = error_types,
    methods = gen_methods('Nvim', api_info.functions, prefixes, false, version or 0)
  }, Api)

  return api
end

Api.basic_types = {}
do
  for k, _ in pairs(type_tables) do
    Api.basic_types[#Api.basic_types+1] = k
  end
end

return Api
