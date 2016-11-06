require('test.asserts')
local table = require('nvim.table')

-----
-- Some data
local tidx_test = {1,2,3,4,5,6,'1','2','3','4','5','6'}
local tkv_test = {
  uno = 1,
  dos = 2,
  tres = 3,
  cuatro = 4,
  cinco = 5,
  seis = 6,
  siete = 7,
  ocho = 8,
  nueve = 9
}

--
-- table_icopy only copies indexed elements
local function test_table_copy(copy_f_name, copy_f, idx_mode, kv_mode) 
  return function (arguments, its)
    local tt = arguments[1]
    describe(copy_f_name, function ()
      it('copying a table returns a new table with the same elements', function()
        local r = copy_f(tt)
        assert.is_not_equal(r, tt)
        assert.contains_same_items(r, tt, idx_mode, kv_mode)
      end)

      it('copying an empty table returns an empty table', function()
        local r = copy_f({})
        assert.True(#r == 0)
      end)

      it('passing an empty table as second arguments works like not passing it', function()
        local r1 = copy_f(tt)
        local t2 = {}
        local r2 = copy_f(tt, t2)
        assert.is_not_equal(r1, tt)
        assert.is_not_equal(r1, r2)
        assert.is_not_equal(r2, tt)
        assert.equal(r2, t2)
        assert.contains_same_items(r1, tt, idx_mode, kv_mode)
        assert.contains_same_items(r1, r2, idx_mode, kv_mode)
      end)

      it('passing an empty table as second argument and an empty table as first argument', function()
        local t2 = {}
        local t1 = {}
        local r1 = copy_f(t1, t2)
        assert.equal(#r1, 0)
        assert.is_equal(r1, t2)
        assert.is.contains_same_items(t1, r1, idx_mode, kv_mode)
      end)
      
      if its then
        its(copy_f, idx_mode, kv_mode)
      end
    end)
  end
end

-- unit test for table.table_icopy
test_table_copy('table.table_icopy', table.table_icopy, true, false)(
  {tidx_test},
  function(copy_f, idx_mode, kv_mode)
    it('passing a table with indices as second argument and an empty table as first argument', function()
      local t2 = {7, 8, 9, '7', '8', '9'}
      local nt2 = #t2
      local r1 = copy_f({}, t2)
      assert.equal(#r1, nt2)
      assert.is_equal(r1, t2)
      assert.is.not_contains_same_items(tidx_test, r1, idx_mode, kv_mode)
    end)
    it('passing a table with indices as second argument and a table with indices as first argument', function()
      local t2 = {7, 8, 9, '7', '8', '9'}
      local nt2 = #t2
      local r1 = copy_f(tidx_test, t2)
      assert.equal(#r1, nt2 + #tidx_test)
      assert.is_equal(r1, t2)
      assert.is_not_equal(r1, tidx_test)
      assert.is.not_contains_same_items(tidx_test, r1, idx_mode, kv_mode)
    end)
    it('ignores completely key-value pairs', function()
      local t1 = {cien = 100, mil = 1000, 1, 2, 3}
      local t2 = {1, 2, 3}
      local r1 = copy_f(t1)
      assert.is_not_equal(r1, t1)
      assert.is_not_equal(r1, t2)
      assert.contains_same_items(r1, t2)
    end)
end)

-- unit test for table.table_copy
test_table_copy('table.table_kvcopy', table.table_kvcopy, false, true)(
  {tkv_test}, 
  function(copy_f, idx_mode, kv_mode)
    it('passing a table with keys as second argument and an empty table as first argument', function()
      local t2 = {cien = 100, mil = 1000}
      local r1 = copy_f({}, t2)
      assert.is_equal(r1, t2)
      assert.is.not_contains_same_items(tkv_test, r1, idx_mode, kv_mode)
    end)
    it('passing a table with keys as second argument and a table with keys as first argument', function()
      local t2 = {cien = 100, mil = 1000}
      local r1 = copy_f(tkv_test, t2)
      assert.is_equal(r1, t2)
      assert.is_not_equal(r1, tkv_test)
      assert.is.not_contains_same_items(tkv_test, r1, idx_mode, kv_mode)
      t2['cien'] = nil
      t2['mil'] = nil
      assert.contains_same_items(tkv_test, t2, idx_mode, kv_mode) 
    end)
    it('ignores completely indexed values', function()
      local t1 = {cien = 100, mil = 1000, 1, 2, 3}
      local t2 = {cien = 100, mil = 1000}
      local r1 = copy_f(t1)
      assert.is_not_equal(r1, t1)
      assert.is_not_equal(r1, t2)
      assert.contains_same_items(r1, t2)
    end)
end)

describe('table.table_filter', function()
  it('Can filter a table with indices', function()
    expected_t = {2, 4, 6, '2', '4', '6'}
    t = table.table_filter(tidx_test, function(v)
      return (tonumber(v) % 2) == 0 
    end)
    assert.contains_same_items(t, expected_t)
  end)
  it('Can filter a table with values', function()
    expected_t = {dos = 2, cuatro = 4, seis = 6, ocho = 8}
    t = table.table_filter(tkv_test, function(v)
      return (tonumber(v) % 2) == 0 
    end)
    assert.contains_same_items(t, expected_t)
  end)
  it('Can filter a table with values and indices', function()
    expected_t = {2, 4, 6, '2', '4', '6', dos = 2, cuatro = 4, seis = 6, ocho = 8}
    t = table.table_filter(table.table_concat(tidx_test, tkv_test), function(v)
      return (tonumber(v) % 2) == 0 
    end)
    assert.contains_same_items(t, expected_t)
  end)
end)

describe('table.table_join', function()
  local custom_t
  before_each(function()
    custom_t = setmetatable({}, {
      __tostring = function(_) 
        return "ThisIsACustomToString"
      end
    })
  end)
  it('Works with empy tables', function()
       assert.equal('', table.table_join({}, ','))
  end)
  it('Works with tables with 1 element', function()
    local _custom_t = setmetatable({}, {
      __tostring = function(_) 
        return "ThisIsACustomToString"
      end
    })
    assert.equal('1', table.table_join({1}, ','))
    assert.equal('true', table.table_join({true}, ','))
    assert.equal('table:',
                 table.table_join({{}}, ','):match('table:'))
    assert.equal('abcdefg', table.table_join({'abcdefg'}, ','))
    assert.equal('ThisIsACustomToString', table.table_join({_custom_t}, ','))
  end)
  it('Works with tables with 1 element', function()
    assert.equal('1', table.table_join({1}, ','))
    assert.equal('true', table.table_join({true}, ','))
    assert.equal('table:',
                 table.table_join({{}}, ','):match('table:'))
    assert.equal('abcdefg', table.table_join({'abcdefg'}, ','))
    assert.equal('ThisIsACustomToString', table.table_join({custom_t}, ','))
  end)
  it('Works with tables with more than 1 element', function()
    assert.equal('1,2', table.table_join({1,2}, ','))
    assert.equal('1,2,3', table.table_join({1,2,3}, ','))
    assert.equal('true,false', table.table_join({true, false}, ','))
    assert.equal('true,false,true', table.table_join({true, false, true}, ','))
    assert.equal('table:',
                 table.table_join({{}}, ','):match('table:'))
    assert.is_not_nil(table.table_join({{}, {}}, ','):match('table: 0.+,table: 0.+'))
    assert.equal('abcdefg', table.table_join({'abcdefg'}, ','))
    assert.equal('abcdefg,hijklm', table.table_join({'abcdefg', 'hijklm'}, ','))

    assert.equal('ThisIsACustomToString',
                 table.table_join({custom_t}, ','))

    assert.equal('ThisIsACustomToString,ThisIsACustomToString',
                 table.table_join({custom_t, custom_t}, ','))
    assert.equal('ThisIsACustomToString,true,666,666,probando', 
                 table.table_join({custom_t, true, 666, '666', 'probando'}, ','))
    assert.equal('ThisIsACustomToString|true|666|666|probando', 
                 table.table_join({custom_t, true, 666, '666', 'probando'}, '|'))
    assert.equal('ThisIsACustomToString|>true|>666|>666|>probando', 
                 table.table_join({custom_t, true, 666, '666', 'probando'}, '|>'))
  end)
end)

describe('table.table_ireduce', function()
  it('It works with empty tables',  function()
    local _, err = table.table_ireduce(function(_, _) return 0 end)({})
    assert.equal(err, 'Could not reduce on an empty table')
  end)
  it('Tables with only kv pairs are like empty tables', function()
    local _, err = table.table_ireduce(function(_, _) return 0 end)({
      uno = 1,
      dos = 2,
      tres = 3
    })
    assert.equal(err, 'Could not reduce on an empty table')
  end)
  it('Can actually reduce tables', function()
    local t1 = {0,0,0,0,0,0,0,0,0,0,0}
    local t2 = {0,1,2,3,4,5,6,7,8,9,10}
    local t3 = {'0','1','2','3','4','5','6','7','8','9'}
    assert.equal(table.table_ireduce(function(a,b)
      return a + b
    end)(t1), 0)
    assert.equal(table.table_ireduce(function(a,b)
      return a + b
    end)(t2), 55)
    assert.equal(table.table_ireduce(function(a,b)
      return a * b
    end)(t2), 0)
    assert.equal(table.table_ireduce(function(a,b)
      return a .. b
    end)(t3), '0123456789')
  end)
end)

describe('table.table_sub', function()
  it('sub in empty tables is always an empty table', function()
    assert.contains_same_items(table.table_sub({}, 0), {})
    assert.contains_same_items(table.table_sub({}, 1), {})
    assert.contains_same_items(table.table_sub({}, 1, 10), {})
    assert.contains_same_items(table.table_sub({}, 1, 0), {})
  end)
 it('sub in tables with only k,v pairs is always an empty table', function()
    local t1 = {
      uno = 1,
      dos = 2,
      tres = 3,
      cuatro = 4
    }
    assert.contains_same_items(table.table_sub(t1, 0), {})
    assert.contains_same_items(table.table_sub(t1, 1), {})
    assert.contains_same_items(table.table_sub(t1, 1, 10), {})
    assert.contains_same_items(table.table_sub(t1, 1, 0), {})
  end)
  it('default iF is always the end of the table / array', function()
    local t1 = {1,2,3,4,5,6,7,8,9,10}
    assert.contains_same_items(table.table_sub(t1, 0), {1,2,3,4,5,6,7,8,9,10})
    assert.contains_same_items(table.table_sub(t1, 0, 10), {1,2,3,4,5,6,7,8,9,10})
    assert.contains_same_items(table.table_sub(t1, 1), {1,2,3,4,5,6,7,8,9,10})
    assert.contains_same_items(table.table_sub(t1, 1, 10), {1,2,3,4,5,6,7,8,9,10})
    assert.contains_same_items(table.table_sub(t1, 1, 0), {})
    assert.contains_same_items(table.table_sub(t1, 1, 9), {1,2,3,4,5,6,7,8,9})
    assert.contains_same_items(table.table_sub(t1, 1, 8), {1,2,3,4,5,6,7,8})
    assert.contains_same_items(table.table_sub(t1, 1, 7), {1,2,3,4,5,6,7})
    assert.contains_same_items(table.table_sub(t1, 1, 6), {1,2,3,4,5,6})
    assert.contains_same_items(table.table_sub(t1, 5, 5), {5})
    assert.contains_same_items(table.table_sub(t1, 10, 1), {})
  end)
end)

describe('table.table_ieq', function()
  it('Empty tables are always equal', function()
    assert.True(table.table_ieq({}, {}))
  end)
  it('We can compare equal tables', function()
    local t1 = {1, 2, 3, 4, 'uno', 'dos', 'tres'}
    local t2 = {1, 2, 3, 4, 'uno', 'dos', 'tres'}
    assert.True(table.table_ieq(t1, t2))
  end)
  it('We can compare not equal tables', function()
    local t1 = {1, 2, 3, 4, 'uno', 'dos', 'tres'}
    local t2 = {1, 2, 3, 4, 'dos', 'tres'}
    assert.False(table.table_ieq(t1, t2))
  end)
  it('We can compare equal tables (ignoring kv pairs)', function()
    local t1 = {1, 2, 3, 4, 'uno', 'dos', 'tres'}
    local t2 = {1, 2, 3, 4, 'uno', 'dos', 'tres', dos = 2}
    assert.True(table.table_ieq(t1, t2))
  end)
  it('We can compare equal tables with nested tables', function()
    local t1 = {1, 2, 3, 4, 'uno', 'dos', 'tres', {5, 6, 7, {8, 9, 10}}}
    local t2 = {1, 2, 3, 4, 'uno', 'dos', 'tres', {5, 6, 7, {8, 9, 10}}}
    assert.True(table.table_ieq(t1, t2))
  end)
  it('We can compare not equal tables with nested tables', function()
    local t1 = {1, 2, 3, 4, 'uno', 'dos', 'tres', {5, 6, 7, {8, 9, 10}}}
    local t2 = {1, 2, 3, 4, 'dos', 'dos', 'tres', {5, 6, 7, {8, 9, 11}}}
    assert.False(table.table_ieq(t1, t2))
  end)
  it('We can compare equal tables with nested tables (ignoring indices)', function()
    local t1 = {1, 2, 3, 4, 'uno', 'dos', 'tres', {5, 6, 7, {8, 9, 10}}}
    local t2 = {1, 2, 3, 4, 'uno', 'dos', 'tres', {5, 6, 7, {8, 9, 10, dumb=1}}}
    assert.True(table.table_ieq(t1, t2))
  end)
end)

describe('table.table_kveq', function()
  it('Empty tables are always equal', function()
    assert.True(table.table_kveq({}, {}))
  end)
  it('We can compare equal tables', function()
    local t1 = {uno = 1, dos = 2, tres = 3, cuatro = 4}
    local t2 = {uno = 1, dos = 2, tres = 3, cuatro = 4}
    assert.True(table.table_kveq(t1, t2))
  end)
  it('We can compare not equal tables', function()
    local t1 = {uno = 1, dos = 2, tres = 3, cuatro = 4}
    local t2 = {uno = 1, dos = 2, tres = 3}
    assert.False(table.table_kveq(t1, t2))
  end)
  it('We can compare equal tables (ignoring indices)', function()
    local t1 = {uno = 1, dos = 2, tres = 3, cuatro = 4}
    local t2 = {uno = 1, dos = 2, tres = 3, cuatro = 4, 1}
    assert.True(table.table_kveq(t1, t2))
  end)
  it('We can compare equal tables with nested tables', function()
    -- {} == {6} in kveq
    local t1 = {uno = 1, dos = 2, tres = 3, cuatro = {cinco = 5, seis = {}}}
    local t2 = {uno = 1, dos = 2, tres = 3, cuatro = {cinco = 5, seis = {6}}}
    assert.True(table.table_kveq(t1, t2))
  end)
  it('We can compare not equal tables with nested tables', function()
    local t1 = {uno = 1, dos = 2, tres = 3, cuatro = {cinco = 5, seis = 6}}
    local t2 = {uno = 1, dos = 2, tres = 3, cuatro = {cinco = 6, seis = 6}}
    assert.False(table.table_kveq(t1, t2))
  end)
  it('We can compare equal tables with nested tables (ignoring indices)', function()
    local t1 = {uno = 1, dos = 2, tres = 3, cuatro = {cinco = 5, seis = 6}}
    local t2 = {uno = 1, dos = 2, tres = 3, cuatro = {1, 2, 3, cinco = 5, seis = 6}}
    assert.True(table.table_kveq(t1, t2))
  end)
end)

describe('table.table_eq', function()
  it('Empty tables are always equal', function()
    assert.True(table.table_eq({}, {}))
  end)
  it('We can compare equal tables', function()
    local t1 = {1, 2, 3, 4, uno = 1, dos = 2, tres = 3, cuatro = 4}
    local t2 = {1, 2, 3, 4, uno = 1, dos = 2, tres = 3, cuatro = 4}
    assert.True(table.table_eq(t1, t2))
  end)
  it('We can compare not equal tables (different dict entries)', function()
    local t1 = {1, 2, 3, 4, uno = 1, dos = 2, tres = 3, cuatro = 4}
    local t2 = {1, 2, 3, 4, uno = 1, dos = 2, tres = 3}
    assert.False(table.table_eq(t1, t2))
  end)
  it('We can compare not equal tables (different indices)', function()
    local t1 = {1, 2, 3, 4, uno = 1, dos = 2, tres = 3, cuatro = 4}
    local t2 = {2, 3, 4, uno = 1, dos = 2, tres = 3, cuatro = nil}
    assert.False(table.table_eq(t1, t2))
  end)
  it('We can compare not equal tables (different dict entries and different indices)', function()
    local t1 = {1, 2, 3, 4, uno = 1, dos = 2, tres = 3, cuatro = 4}
    local t2 = {1, 2, 3, uno = 1, dos = 2, tres = 3}
    assert.False(table.table_eq(t1, t2))
  end)
  it('We can compare equal tables with nested tables', function()
    local t1 = {uno = 1, dos = 2, tres = 3, cuatro = {cinco = 5, seis = 6}}
    local t2 = {uno = 1, dos = 2, tres = 3, cuatro = {cinco = 5, seis = 6}}
    assert.True(table.table_eq(t1, t2))
  end)
  it('We can compare not equal tables with nested tables (different nested indices)', function()
    local t1 = {uno = 1, dos = 2, tres = 3, cuatro = {1, 2, 3, cinco = 5, seis = 6}}
    local t2 = {uno = 1, dos = 2, tres = 3, cuatro = {1, 2, cinco = 5, seis = 6}}
    assert.False(table.table_eq(t1, t2))
  end)
  it('We can compare not equal tables with nested tables (different nested dict entries)', function()
    local t1 = {uno = 1, dos = 2, tres = 3, cuatro = {1, 2, 3, cinco = 5, seis = 6}}
    local t2 = {uno = 1, dos = 2, tres = 3, cuatro = {1, 2, 3, cinco = 6, seis = 6}}
    assert.False(table.table_eq(t1, t2))
  end)
end)

describe('table.table_iconcat', function()
  it('We can concat empty tables', function()
    local t1 = {1,2,3,4,5,6}
    assert.contains_same_items(table.table_iconcat({}, {}), {})
    assert.contains_same_items(table.table_iconcat(t1, {}), t1)
    assert.contains_same_items(table.table_iconcat({}, t1), t1)
  end)
  it('tables with k,v pairs are like empty tables', function()
    local t1 = {1,2,3,4,5,6}
    local t2 = {
      uno = 1,
      dos = 2,
      tres = 3
    }
    assert.contains_same_items(table.table_iconcat(t2, t2), {})
    assert.contains_same_items(table.table_iconcat(t1, t2), t1)
    assert.contains_same_items(table.table_iconcat(t2, t1), t1)
  end)
  it('We can actually concat tables', function()
    local t1 = {1,2,3,4,5}
    local t2 = {6,7,8,9,10}
    local t12 = {1,2,3,4,5,6,7,8,9,10}
    local t21 = {6,7,8,9,10,1,2,3,4,5}
    local t11 = {1,2,3,4,5,1,2,3,4,5}
    local t22 = {6,7,8,9,10,6,7,8,9,10}
    assert.contains_same_items(table.table_iconcat(t1, t2), t12)
    assert.contains_same_items(table.table_iconcat(t2, t1), t21)
    assert.contains_same_items(table.table_iconcat(t1, t1), t11)
    assert.contains_same_items(table.table_iconcat(t2, t2), t22)
  end)
end)
  
describe('table.table_concat', function()
  it('We can concat empty tables', function()
    local t1 = {
      uno = 1,
      dos = 2,
      tres = 3
    }
    assert.contains_same_items(table.table_concat({}, {}), {})
    assert.contains_same_items(table.table_concat(t1, {}), t1)
    assert.contains_same_items(table.table_concat({}, t1), t1)
  end)
  it('tables with indexed items are like also copied', function()
    local t2 = {1,2,3,4,5,6}
    local t1 = {
      uno = 1,
      dos = 2,
      tres = 3
    }
    local t12 = {
      1,2,3,4,5,6,
      uno = 1,
      dos = 2,
      tres = 3
    }
    local t21 = t12
    -- indices now are no copied if they are the same, see the difference with iconcat
    assert.contains_same_items(table.table_concat(t2, t2), t2)
    assert.contains_same_items(table.table_concat(t1, t2), t12)
    assert.contains_same_items(table.table_concat(t2, t1), t21)
  end)
  it('We can actually concat tables', function()
    local t1 = {
      uno = 1,
      dos = 2,
      tres = 3
    }
    local t2 = {
      cuatro = 4,
      cinco = 5,
      seis = 6
    }
    local t12 = {
      uno = 1,
      dos = 2,
      tres = 3,
      cuatro = 4,
      cinco = 5,
      seis = 6
    }
    local t21 = t12
    assert.contains_same_items(table.table_concat(t1, t2), t12)
    assert.contains_same_items(table.table_concat(t2, t1), t21)
    assert.contains_same_items(table.table_concat(t1, t1), t1)
    assert.contains_same_items(table.table_concat(t2, t2), t2)
  end)
end)

