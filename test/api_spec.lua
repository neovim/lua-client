require("test.asserts")
local api = require("nvim.api")
local mocked_session = require("test.mocked_session")
local t = table
local tt = require("nvim.table")

local function function_names(functions)
  local xs = tt.table_fmap(functions, function(fname, f)
    return nil, fname
  end)
  t.sort(xs)
  return xs
end

describe("Api", function()
  local mocked_session1
  local mocked_session1_data
  before_each(function()
    mocked_session1_data = assert(loadfile("test/api1.lua"))()
    mocked_session1 = mocked_session.new(mocked_session1_data)
  end)

  it("creates api",
  function()
    local api = api.new(mocked_session1)
    local result = function_names(api.functions)
    assert.contains_same_items(result, {
      "f1", "f2", "f3", "f4", "f5", "f6"
    })
  end)

  it("does not create api if api_level < api_compatible",
  function()
    mocked_session1_data.version.api_compatible = 2
    local s = mocked_session.new(mocked_session1_data)
    local api, err = api.new(s, 1)
    assert.is_nil(api)
    assert.are.equals(err, "api_level 1 not compatible with Nvim version")
  end)

  it("does not create api if api_level < api_compatible",
  function()
    local s = mocked_session.new(mocked_session1_data)
    local api, err = api.new(s, 4)
    assert.is_nil(api)
    assert.are.equals(err, "api_level 4 not compatible with Nvim version")
  end)

  it("creates api ignoring deprecated",
  function()
    local api = api.new(mocked_session1, nil, true)
    local result = function_names(api.functions)
    assert.contains_same_items(result, {
      "f1", "f2", "f3"
    })
  end)

  it("creates api, api level 3",
  function()
    local api = api.new(mocked_session1, 3)
    local result = function_names(api.functions)
    assert.contains_same_items(result, {
      "f1", "f2", "f3", "f4", "f5", "f6"
    })
  end)

  it("create api, api level 2",
  function()
    local api = api.new(mocked_session1, 2)
    local result = function_names(api.functions)
    assert.contains_same_items(result, {
      "f1", "f2", "f4"
    })
  end)

  it("creates api, api level 1",
  function()
    local api = api.new(mocked_session1, 1)
    local result = function_names(api.functions)
    assert.contains_same_items(result, {
      "f1"
    })
  end)

  it("creates api, api level 2 and deprecated mode",
  function()
    local api = api.new(mocked_session1, 2, true)
    local result = function_names(api.functions)
    assert.contains_same_items(result, {
      "f1", "f2"
    })
  end)

  it("only uses compatible api functions", 
  function()
    mocked_session1_data.version.api_compatible = 2
    local s = mocked_session.new(mocked_session1_data)
    local api = api.new(s)
    local result = function_names(api.functions)
    assert.contains_same_items(result, {
      "f2", "f3", "f4", "f5", "f6"
    })
  end)

end)
