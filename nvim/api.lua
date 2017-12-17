local table = require "nvim.table"
local sfmt = string.format

-- Classes defined in this module
local Api = {}

local function nvim_fn_wrapper(session, fn_name)
  return function(...)
    local args = {...}
    -- nvim api returns the status as first value and the result | error as second
    local success, returned_value = session:request(fn_name, unpack(args))
    if not success then
      -- res contains error on failure
      return nil, returned_value
    end
    return returned_value
  end
end

local function gen_functions(functions, session, api_level, api_compatible, include_deprecated)
  -- require version 0 by default
  return table.table_fmap(functions, function(_, func)
    -- Filter only functions starting with prefix_name as methods
    -- Also replace prefix
    local deprecated_since = func.deprecated_since or api_level + 1
    if func.since <= api_level and func.since >= api_compatible then
      if not include_deprecated or deprecated_since > api_level then
        return func.name, nvim_fn_wrapper(session, func.name)
      end
    end
    return nil
  end)
end

Api.__index = function(api, k)
  local fn = api.functions[k]
  if fn then
    -- TODO: This code is a repetition of instance__index, generalize it!
    return function(...)
      local arg = {...}
      return api.functions[k](unpack(arg))
    end
  else
    return nil
  end
end

--- Returns an instance of (Nvim) Api
-- Session: session used by the client
-- ?number: version specifies minimum version to use, does not include functions/methods
-- deprecated since the specified version. If nil all functions/methods are included
-- treturn: Api
function Api.new(session, api_level, include_deprecated)
  local ok, res = session:request("vim_get_api_info")
  local _, api_info
  if ok then
    _, api_info = unpack(res)
  else
    return nil, "Error getting api info"
  end
  local current_api_level = api_info.version.api_level
  local current_api_compatible = api_info.version.api_compatible
  local requested_api_level = api_level or current_api_level
  if api_level then
    if not (current_api_compatible <= api_level and api_level <= current_api_level) then
      return nil, sfmt("api_level %s not compatible with Nvim version", api_level)
    end
  end
  local api = setmetatable({
    _api_info = api_info,
    _session = session,
    functions = gen_functions(api_info.functions, session, requested_api_level, current_api_compatible,
                              include_deprecated or false)
  }, Api)

  return api
end

return Api
