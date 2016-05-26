local deps_prefix = './.deps/usr'
if os.getenv('DEPS_PREFIX') then
  deps_prefix = os.getenv('DEPS_PREFIX')
end
package.path =
     deps_prefix
  .. '/share/lua/5.1/?.lua;' .. deps_prefix .. '/share/lua/5.1/?/init.lua;'
  .. package.path
package.cpath =
     deps_prefix
  .. '/lib/lua/5.1/?.so;'
  .. package.cpath
local assert = require("luassert")
local say = require('say')

-- asserts that two tables contains the same items using idexed items
local function assert_idx_mode(t1, t2)
  for i, v in ipairs(t1) do
    if type(v) == 'table' then
      if type(t2[i]) == 'table' then
        if not assert_idx_mode(v, t2[i]) then
          return false
        end
      else
        return false
      end
    elseif(v ~= t2[i]) then
      return false
    end
  end
  return #t1 == #t2
end

-- asserts that two tables contains the same items using k-v pairs
local function assert_kv_mode(t1, t2)
  local visited = {}
  for k, v in pairs(t1) do
    if type(k) ~= 'number' then
      if type(v) == 'table' then
        if type(t2[k]) == 'table' then
          if not assert_kv_mode(v, t2[k]) then
            return false
          end
        else
          return false
        end
      elseif (v ~= t2[k]) then return false end
      visited[k] = v
    end
  end
  for k, _ in pairs(t2) do
    if type(k) ~= 'number' and not visited[k] then
      return false
    end
  end
  return true
end

-- asserts that two tables contains the same items
local function assert_full_mode(t1, t2)
  return assert_idx_mode(t1, t2) and assert_kv_mode(t1, t2)
end

local function contains_same_items(_, arguments)
  local t1 = arguments[1]
  local t2 = arguments[2]
  local idx_mode = arguments[3] -- check only idexed values, list mode
  local kv_mode = arguments[4] -- check only key-value pairs, dict mode
  if idx_mode then 
    return assert_idx_mode(t1, t2)  
  elseif kv_mode then
    return assert_kv_mode(t1, t2)
  else
    return assert_full_mode(t1, t2)
  end
end

say:set_namespace("en")
say:set('assertion.contains_same_items.positive',
        'Expected %s to contain the same items that:\n%s')
say:set('assertion.contains_same_items.negative',
        'Expected %s to contain different items that:\n%s')
assert:register('assertion', 'contains_same_items', contains_same_items,
                'assertion.contains_same_items.positive',
                'assertion.contains_same_items.negative')

local function string_assert(mode)
  local prepare_args = function(state, arguments)
    local container = arguments[1]
    local content = arguments[2]
    if type(container) ~= 'string' then
      state.failure_message = 'First argument must to be a string'
      return nil
    end
    if type(content) ~= 'string' then
      state.failure_message = 'Second argument must to be a string'
      return nil
    end
    return container, content
  end

  if mode == 'start' then
    return function(state, arguments) 
      local container, content = prepare_args(state, arguments)
      if not container then return false end
      if container:match("^" .. content) then
        return true
      else
        return false
      end
    end
  elseif mode == 'middle' then
    return function(state, arguments) 
      local container, content = prepare_args(state, arguments)
      if not container then return false end
      if container:match(content) then
        return true
      else
        return false
      end
    end
  elseif mode == 'end' then
    return function(state, arguments) 
      local container, content = prepare_args(state, arguments)
      if not container then return false end
      if container:match(content .. '$') then
        return true
      else
        return false
      end
    end
  else
    return function(state)
      state.failure_message = 'Unknown string assertion'
      return false
    end
  end
end

say:set('assertion.starts_with.positive',
        'Expected %s to start with: \n%s')
say:set('assertion.starts_with.negative',
        'Expected %s not to start with: \n%s')
assert:register('assertion', 'starts_with', string_assert('start'),
                'assertion.starts_with.positive',
                'assertion.starts_with.negative')

say:set('assertion.contains.positive',
        'Expected %s to contain: \n%s')
say:set('assertion.contains.negative',
        'Expected %s not to contain: \n%s')
assert:register('assertion', 'contains', string_assert('middle'),
                'assertion.contains.positive',
                'assertion.contains.negative')

say:set('assertion.ends_with.positive',
        'Expected %s to end with: \n%s')
say:set('assertion.ends_with.negative',
        'Expected %s not to end with: \n%s')
assert:register('assertion', 'ends_with', string_assert('end'),
                'assertion.ends_with.positive',
                'assertion.ends_with.negative')

