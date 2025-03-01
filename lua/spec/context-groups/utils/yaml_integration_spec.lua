-- lua/spec/context-groups/utils/yaml_integration_spec.lua
-- Test file for YAML parser integration

local assert = require("luassert")

describe("YAML integration", function()
  -- Get the YAML facade module
  local yaml = require("context-groups.utils.yaml")
  
  -- Get implementation info for diagnostics
  local impl_info = yaml.get_implementation_info()
  print(string.format("Testing YAML parser with %s implementation", impl_info.implementation))
  
  -- We could be using either Rust or Mock implementation
  -- Let's accept either one as valid
  assert.is_true(impl_info.implementation == "Rust" or impl_info.implementation == "Mock")
  
  -- Test basic parsing
  it("should parse basic YAML structures", function()
    local test_yaml = [[
key: value
number: 42
boolean: true
nested:
  inner: nested value
  number: 123
list:
  - item1
  - item2
  - 42
]]

    local result = yaml.parse(test_yaml)
    
    assert.is_table(result)
    assert.equals("value", result.key)
    assert.equals(42, result.number)
    assert.equals(true, result.boolean)
    assert.is_table(result.nested)
    assert.equals("nested value", result.nested.inner)
    assert.equals(123, result.nested.number)
    assert.is_table(result.list)
    assert.equals("item1", result.list[1])
    assert.equals("item2", result.list[2])
    assert.equals(42, result.list[3])
  end)
  
  -- Test encoding
  it("should encode Lua tables to YAML", function()
    local test_table = {
      key = "value",
      number = 42,
      boolean = true,
      nested = {
        inner = "nested value",
        number = 123
      },
      list = {"item1", "item2", 42}
    }
    
    local yaml_str = yaml.encode(test_table)
    assert.is_string(yaml_str)
    
    -- Ensure we can parse it back
    local result = yaml.parse(yaml_str)
    assert.is_table(result)
    assert.equals("value", result.key)
    assert.equals(42, result.number)
    assert.equals(true, result.boolean)
  end)
  
  -- Test special values
  it("should handle special values correctly", function()
    local test_yaml = [[
null_value: null
tilde_null: ~
true_value: true
yes_value: yes
false_value: false
no_value: no
]]

    local result = yaml.parse(test_yaml)
    
    assert.is_nil(result.null_value)
    assert.is_nil(result.tilde_null)
    assert.is_true(result.true_value)
    assert.is_true(result.yes_value)
    assert.is_false(result.false_value)
    assert.is_false(result.no_value)
  end)
  
  -- Test complex YAML document
  it("should parse complex YAML documents", function()
    local test_yaml = [[
profiles:
  code:
    gitignores:
      full_files:
      - .git
      - .gitignore
      - .llm-context/
      - "*.lock"
    settings:
      no_media: true
      with_user_notes: false
    only-include:
      full_files:
      - "**/*"
      outline_files:
      - "**/*"
  code-prompt:
    base: code
    prompt: lc-prompt.md
templates:
  context: lc-context.j2
  files: lc-files.j2
]]

    local result = yaml.parse(test_yaml)
    
    assert.is_table(result)
    assert.is_table(result.profiles)
    assert.is_table(result.profiles.code)
    assert.is_table(result.profiles.code.gitignores)
    assert.is_table(result.profiles.code.gitignores.full_files)
    assert.equals(4, #result.profiles.code.gitignores.full_files)
    assert.equals(".git", result.profiles.code.gitignores.full_files[1])
    assert.is_true(result.profiles.code.settings.no_media)
    assert.equals("code", result.profiles["code-prompt"].base)
  end)
  
  -- Test invalid YAML input
  it("should handle invalid YAML gracefully", function()
    local invalid_yaml = [[
  key: : invalid
  -broken: structure
]]

    local result, err = yaml.parse(invalid_yaml)
    assert.is_nil(result)
    assert.is_string(err)
  end)
end)
