require('test.asserts')
local api = require('nvim.api')
local mocked_session = require('test.mocked_session')
local table = require('nvim.table')

-----
-- Some data
local functions1 = {
  {
    name = "nvim_test",
    return_type = "Integer",
    parameters = { { "Integer", "a" } }
  },
  {
    name = "nvim_buf_get_line",
    return_type = "String",
    parameters = { { "Buffer", "buffer" }, { "Integer", "index" } }
  },
  {
    name = "nvim_win_set_line",
    return_type = "void",
    parameters = { { "Buffer", "buffer" }, { "Integer", "index" }, { "String", "line" } }
  }
}
local functions2 = {
  {
    name = "integer_test",
    return_type = "Integer",
    parameters = { { "Integer", "a" } }
  },
  {
    name = "integer_get_line",
    return_type = "String",
    parameters = { { "Buffer", "buffer" }, { "Integer", "index" } }
  },
  {
    name = "integer_set_line",
    return_type = "void",
    parameters = { { "Buffer", "buffer" }, { "Integer", "index" }, { "String", "line" } }
  }
}
local functions3 = {
  {
    name = "nvim_buf_fun1",
    return_type = "Integer",
    parameters = { { "Integer", "a" } }
  },
  {
    name = "nvim_buf_fun2",
    return_type = "String",
    parameters = { { "Buffer", "buffer" }, { "Integer", "index" } }
  },
  {
    name = "nvim_buf_fun3",
    return_type = "void",
    parameters = { { "Buffer", "buffer" }, { "Integer", "index" }, { "String", "line" } }
  },
  {
    name = 'nvim_win_fun1',
    return_type = 'ArrayOf(Integer)',
    parameters = {}
  },
  {
    name = 'nvim_tabpage_fun1',
    return_type = 'ArrayOf(Integer)',
    parameters = {}
  }
}

local function has_basic_types(types, exclude_types)
  local expected_basic_types = {
    Nil = true,
    Boolean = true,
    Integer = true,
    Float = true,
    String = true,
    Array = true,
    ArrayOf = true,
    Dictionary = true,
    void = true,
    Object = true
  }
  local type_names = {}
  for k, _ in pairs(types) do
    if not (exclude_types or {})[k] then
      type_names[k] = true 
    end
  end
  assert.contains_same_items(type_names, expected_basic_types, false, true)
end

describe('Api', function()
  it('we can create a new api from session', function()
    local types = api.new(mocked_session.new({
      ext_types = {},
    }))._types
    -- basic types only
    has_basic_types(types)
    -- Check that methods are empty in all the basic types
    for _, v in pairs(types) do
      assert.contains_same_items(v.methods, {}, false, true)
    end
  end)

  it('can create basic types without ext_types', function()
    local types = api.new(mocked_session.new({
      ext_types = {},
      functions = functions1
    }))._types  
    has_basic_types(types)
    -- Check that methods are empty in all the basic types
    for _, v in pairs(types) do
      assert.contains_same_items(v.methods, {}, false, true)
    end
  end)

  it('basic types never get methods from the api', function()
    local types = api.new(mocked_session.new({
      ext_types = {},
      functions = functions2
    }))._types
    has_basic_types(types)
    -- Check that methods are empty in all the basic types
    for _, v in pairs(types) do
      assert.contains_same_items(v.methods, {}, false, true)
    end
  end)

  it('we can generate ext_types without methods', function()
    local types = api.new(mocked_session.new({
      ext_types = {Buffer = {}},
      functions = functions2
    }))._types
    has_basic_types(types, {Buffer = true})
    -- Check that methods are empty in all the basic types
    for _, v in pairs(types) do
      assert.contains_same_items(v.methods, {}, false, true)
    end
    -- Check that the buffer type was created without methods
    assert.equal(type(types.Buffer), 'table')
    assert.contains_same_items(types.Buffer.methods, {})
  end)

  -- This basically tests that we can get methods for nvim and for different
  -- types like window (nvim_window) and buffer (nvim_buf). It also checks that
  -- functions prefixed with nvim_* being the * the same prefix as in a type are 
  -- not included in Nvim client but in concrete types
  it('prefixes works when generating types and methods', function()
    local api = api.new(mocked_session.new({
      ext_types = {Buffer = {prefix = 'nvim_buf_'}, Window = {prefix = 'nvim_win_'}},
      functions = functions1
    }))
    has_basic_types(api._types, {Buffer = true, Window = true})
    -- Check that methods are empty in all the basic types
    for _, v in pairs(api._types) do
      if v._name ~= 'Buffer' and v._name ~= 'Window' then
        assert.contains_same_items(v.methods, {}, false, true)
      end
    end

    assert.equal(type(api.methods), 'table')
    assert.equal(type(api.methods.test), 'table')
    assert.equal(table.table_len(api.methods), 1)
    
    -- Check that the buffer type have been created just with 1 method
    -- nvim_ methods have been filtered out
    assert.equal(type(api._types.Buffer), 'table')
    assert.equal(type(api._types.Buffer.methods.get_line), 'table')
    assert.equal(table.table_len(api._types.Buffer.methods), 1)
    
    -- Check that the window type have been created just with 1 method
    -- nvim_ methods have been filtered out
    assert.equal(type(api._types.Window), 'table')
    assert.equal(type(api._types.Window.methods.set_line), 'table')
    assert.equal(table.table_len(api._types.Window.methods), 1)
  end)

  it('we can generate ext_types with methods', function()
    local types = api.new(mocked_session.new({
      ext_types = {Buffer = {prefix = 'nvim_buf_'}, Window = {prefix = 'nvim_win_'}}, 
      functions = functions3
    }))._types
    has_basic_types(types, {Buffer = true, Window = true})
    -- Check that methods are empty in all the basic types
    for _, v in pairs(types) do
      if v.basic_type then
        assert.contains_same_items(v.methods, {}, false, true)
      end
    end
    -- Check that the buffer type was created with methods
    assert.equal(type(types.Buffer), 'table')
    local buffer_methods = types.Buffer.methods
    assert.equal(type(buffer_methods.fun1), 'table')
    assert.equal(type(buffer_methods.fun2), 'table')
    assert.equal(type(buffer_methods.fun3), 'table')
    -- Check that it use self notation
    assert.equal(buffer_methods.fun1._uses_self, true)
    assert.equal(buffer_methods.fun2._uses_self, true)
    assert.equal(buffer_methods.fun3._uses_self, true)
    -- Check that we have the underlaying vim function
    assert.contains_same_items(buffer_methods.fun1._nvim_function, functions3[1])
    assert.contains_same_items(buffer_methods.fun2._nvim_function, functions3[2])
    assert.contains_same_items(buffer_methods.fun3._nvim_function, functions3[3])
    --
    -- Check that the window type was created with methods
    assert.equal(type(types.Window), 'table')
    local window_methods = types.Window.methods
    assert.equal(type(window_methods.fun1), 'table')
    -- Check that it use self notation
    assert.equal(window_methods.fun1._uses_self, true)
    -- Check that we have the underlaying vim function
    assert.contains_same_items(window_methods.fun1._nvim_function, functions3[4])
  end)

  it('Api:get_type returns a type if it exists', function()
    local _api = api.new(mocked_session.new({
      ext_types = {Buffer = {}, Window = {}, Tabpage = {}, MyType = {}},
      functions = functions3
    }))
    assert.is_not_nil(_api:get_type('Buffer'))
    assert.is_not_nil(_api:get_type('Window'))
    assert.is_not_nil(_api:get_type('Tabpage'))
    assert.is_not_nil(_api:get_type('MyType'))
    assert.is_not_nil(_api:get_type('Integer'))
    assert.is_not_nil(_api:get_type('Float'))
    assert.is_not_nil(_api:get_type('String'))
    assert.is_not_nil(_api:get_type('Dictionary'))
    assert.is_not_nil(_api:get_type('Array'))
    assert.is_not_nil(_api:get_type('ArrayOf(Integer)'))
  end)

  it('Api:get_type returns nil if a type does not exist', function()
    local _api = api.new(mocked_session.new({
      ext_types = {Buffer = {}, Window = {}, Tabpage = {}},
      functions = functions3
    }))
    assert.is_nil(_api:get_type('MyType'))
  end)

  describe('argument types when calling methods', function()
    before_each(function()
      api = api.new(mocked_session.new({}))
    end)
    it('can be validated', function()
      local buffer = api:get_type('Buffer').new({})
      local _, err = buffer:fun1("aaa")
      assert.equal(err, 'Error on parameter #2: Expected Integer, got `aaa`(string)')
      _, err = buffer:fun1()
      assert.equal(err, 'Error on parameter #2: Expected Integer, got `nil`(nil)')
    end)
    it('can accumulate errors', function()
      local buffer = api:get_type('Buffer').new({})
      local _, err = buffer.fun1("aaa")
      assert.equal(err, 'Error on parameter #1: Expected Buffer, got `aaa`(string)|Error on parameter #2: Expected Integer, got `nil`(nil)')
    end)
  end)
  describe('return value when calling methods', function()
    before_each(function()
      api = api.new(mocked_session.new({}))
    end)
    it('can be validated detecting errors', function()
      local buffer = api:get_type('Buffer').new({})
      local _, err = buffer:bad_fun2()
      assert.equal(err, 'Expected String, got `true`(boolean)')
      _, err = buffer:bad_fun1()
      assert.equal(err, 'Expected String, got `nil`(nil)')
      assert.equal(buffer:fun2(124), '124')
    end)
    it('can validate Strings', function()
      local buffer = api:get_type('Buffer').new({})
      assert.equal(buffer:fun2(124), '124')
    end)
    it('can validate Integers', function()
      local buffer = api:get_type('Buffer').new({})
      assert.equal(buffer:fun1(10), 100)
    end)
    it('Integers are validate as Floats', function()
      local buffer = api:get_type('Buffer').new({})
      assert.equal(buffer:fun8(), 13)
    end)
    it('Floats are not validated as Integers', function()
      local buffer = api:get_type('Buffer').new({})
      assert.equal(buffer:fun7(), 13.1416)
    end)
    it('can validate Floats', function()
      local buffer = api:get_type('Buffer').new({})
      assert.equal(buffer:fun4(), 13.1416)
    end)
    it('can validate Booleans', function()
      local buffer = api:get_type('Buffer').new({})
      assert.equal(buffer:fun5(), true)
    end)
    it('can validate void', function()
      local res, err
      local buffer, _ = api:get_type('Buffer').new({})
      res, err = buffer:fun3()
      assert.is_nil(err)
      assert.equal(res, nil)
    end)
    it('can validate Nil', function()
      local res, err
      local buffer, _ = api:get_type('Buffer').new({})
      res, err = buffer:fun6()
      assert.is_nil(err)
      assert.equal(res, nil)
    end)
    it('can validate Arrays', function()
      local tabpage = api:get_type('Tabpage').new({})
      assert.contains_same_items(tabpage:fun1(), {1, 2, 3.1416, '1', '2', '3.1416', true})
    end)
    it('can validate Dictionaries', function()
      local window = api:get_type('Window').new({})
      assert.contains_same_items(window:fun2(), {
        uno = 1,
        dos = 2,
        tres = 'tres',
        cuatro = true,
      })
    end)
    it('can validate ArrayOf', function()
      local window = api:get_type('Window').new({})
      assert.contains_same_items(window:fun1(), {1,2,3,4,5,6})
    end)
    it('ArrayOf(Integer) validation fails when any of the items is not an Integer', function()
      local window = api:get_type('Window').new({})
      local _, err = window:bad_fun1()
      assert.equal(err, 'Expected ArrayOf[Integer[nvim type]] but we found `6`(string)')
    end)
    it('We can chain methods', function()
      local window = api:get_type('Window').new({})
      local tabpage = window:fun3()
      assert.starts_with(tostring(tabpage), 'Tabpage%[nvim ext type%]')
      local buffer = tabpage:fun2()
      assert.contains(tostring(buffer), 'Buffer%[nvim ext type%]')
      local window2, _ = buffer:fun9()
      assert.starts_with(tostring(window2), 'Window%[nvim ext type%]')
    end)
  end)
end)
