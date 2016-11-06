------------
-- table
-- utility functions
-- module: table

local Table = {}

-----
-- returns a copy of a table
-- this function copies a table, it filters elements computing
-- filter_f(key). Keys returning true are copied, and the new 
-- key is computed using key_f(n, key), where n is the index of 
-- the current key
--
-- {A, ...}: t1 table to copy
-- {A, ...}?: t2 optional table to use as destination
-- A -> boolean: filter_f function to filter keys
-- (number -> boolean) -> A
-- treturn: {A, ...}
function Table.table_copy(t1, t2, filter_f, key_f)
  local f = filter_f or function (_, _) return true end
  local g = key_f or function (_, k) return k end
  local _t = t2 or {}
  for k, v in pairs(t1) do
    if f(k, v) then
      _t[g(#_t, k)] = v
    end
  end

  return _t
end

-----
-- filters elements of t1 using the filter function filter_f
-- t1 can be an indexed list, a dictionary or a mix of boths
-- {A, ...}: t1 table to filter
-- A -> B -> boolean: filter_f1 function taking index and value and returning boolean
-- if the function returns true the element is not filtered otherwise it's filtered
-- treturn: {A, ...}
function Table.table_filter(t1, filter_f)
  return Table.table_copy(t1, {}, 
    function(_, v) return filter_f(v) end,
    function(i, v) 
      if type(v) ~= "number" then
        return v
      else
        return i + 1
      end
    end)
end

-----
-- copies all key,value pairs from a table (dictionary) into another.
--
-- {A = B, ...}: t1 table to copy
-- {A = B,, ...}?: t2 optional table to use as destination
-- treturn: {A = B, ...}
function Table.table_kvcopy(t1, t2)
  return Table.table_copy(t1, t2,
    function(k) return type(k) ~= 'number' end,
    nil)
end

-----
-- copies all indexed items from a table (list) into another
--
-- {A, ...}: t1 table to copy
-- {A, ...}?: t2 optional table to use as destination
-- treturn: {A, ...}
function Table.table_icopy(t1, t2)
  return Table.table_copy(t1, t2,
    function(k) return type(k) == 'number' end,
    function(n, _) return n + 1 end)
end

-- asserts that two tables contains the same items using idexed items
local function eq_idx_mode(t1, t2, cmp_f)
  for i, v in ipairs(t1) do
    if type(v) == 'table' then
      if type(t2[i]) == 'table' then
        if not (cmp_f or eq_idx_mode(v, t2[i])) then
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
local function eq_kv_mode(t1, t2, cmp_f)
  local visited = {}
  for k, v in pairs(t1) do
    if type(k) ~= 'number' then
      if type(v) == 'table' then
        if type(t2[k]) == 'table' then
          if not (cmp_f or eq_kv_mode)(v, t2[k]) then
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

-----
-- compares two tables (dictionary mode)
--
-- {A = B, ...}: t1 to compare
-- {A = B, ...}: t2 to compare
-- ({...}, {...}) -> boolean: f function to compare
-- treturn: boolean
function Table.table_kveq(t1, t2, cmp_f)
  local visited = {}
  for k, v in pairs(t1) do
    if type(k) ~= 'number' then
      if type(v) == 'table' then
        if type(t2[k]) == 'table' then
          if not (cmp_f or eq_kv_mode)(v, t2[k], cmp_f) then
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

-----
-- compares two tables (list mode)
--
-- {A = B, ...}: t1 to compare
-- {A = B, ...}: t2 to compare
-- ({...}, {...}) -> boolean: function to compare
-- treturn: boolean
function Table.table_ieq(t1, t2, cmp_f)
  for i, v in ipairs(t1) do
    if type(v) == 'table' then
      if type(t2[i]) == 'table' then
        if not (cmp_f or eq_idx_mode)(v, t2[i], cmp_f) then
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

-----
-- compares two tables (dictionary and list mode)
--
-- {A = B, ...}: t1 to compare
-- {A = B, ...}: t2 to compare
-- treturn: boolean
function Table.table_eq(t1, t2)
  local f
  -- We need to pass ourselves to both eq functions, so when we compare
  -- nested tables we use table_eq on them.
  f = function(_t1, _t2)
    return Table.table_ieq(_t1, _t2, f) and Table.table_kveq(_t1, _t2, f)
  end
  return f(t1, t2)
end

-----
-- returns a subtable from a table, only indexed items
--
-- {A, ...}: t table to get the subtable from
-- number: i0 position to take the first element from
-- number?: iF position to take the last element from (last item of t by default)
-- treturn: {A, ...}
function Table.table_sub(t, i0, iF)
  local _t = {}
  for i=i0, (iF or #t) do
    _t[#_t+1] = t[i]
  end
  return _t
end

-----
-- returns a copy of the concatenation of t1 and t2 (indexed items only)
-- {A, ...}: t1 first table to copy
-- {B, ...}: t2 second table to copy
-- treturn: {A, ..., B, ...} copy of t1 `concat` t2
function Table.table_iconcat(t1, t2)
  return Table.table_icopy(t2, Table.table_icopy(t1))
end

-----
-- returns a copy of the concatenation of t1 and t2 (all items)
-- {A, ...}: t1 first table to copy
-- {B, ...}: t2 second table to copy
-- treturn: {A, ..., B, ...} copy of t1 `concat` t2
function Table.table_concat(t1, t2)
  return Table.table_copy(t2, Table.table_copy(t1))
end

-----
-- maps every key,value pair in a table returning a new table
-- {A = B, ...}: t table to map
-- (A, B) -> C, D: f function to map
-- treturn: {D = D, ...}
function Table.table_fmap(t, f)
  local _t = {}
  for k, v in pairs(t) do
    local success, _k, _v = pcall(f, k, v)
    if success and _k then
      _t[_k] = _v
    end
  end

  return _t
end

-----
-- foldr indexed elements in a table
-- A: r0 initial value
-- (A, A) -> A: f function to foldr
-- treturn {A, ...} -> A
function Table.table_ifoldr(r0, f)
  return function(t)
    local r = r0
    for _, v in ipairs(t) do
      r = f(r, v)
    end
    return r
  end
end

-----
-- reduces indexed elements in a table
-- (A, A) -> A: f function to reduce
-- treturn {A, ...} -> A
function Table.table_ireduce(f)
  return function(t)
    local r0 = t[1]
    if r0 then
      local _t = Table.table_icopy(t)
      table.remove(_t, 1)
      return Table.table_ifoldr(r0, f)(_t)
    else
      return nil, 'Could not reduce on an empty table'
    end
  end
end

-----
-- joins indexed items in a table creating a string
-- {A, }: t table with items to join (items must to implement __tostring)
-- string: sep string to use as separator between items
-- treturn string
function Table.table_join(t, sep)
  if #t == 0 then return "" end
  local t_strings = Table.table_fmap(t, function(k, v) return k, tostring(v) end)
  return Table.table_ireduce(function(a, b)
    local d = string.format('%s%s%s', tostring(a), sep, tostring(b)) 
    return d
  end)(t_strings)
end

return Table

