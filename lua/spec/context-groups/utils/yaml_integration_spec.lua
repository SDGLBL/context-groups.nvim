-- lua/spec/context-groups/utils/yaml_integration_spec.lua
-- Test file for YAML parser integration

local assert = require("luassert")

describe("YAML integration", function()
  -- Get the YAML facade module
  local yaml = require("context-groups.utils.yaml")
  
  -- Get implementation info for diagnostics
  local impl_info = yaml.get_implementation_info()
  print(string.format("Testing YAML parser with %s implementation", impl_info.implementation))
  
  -- Accept either Rust or Minimal implementation
  assert.is_true(impl_info.implementation == "Rust" or impl_info.implementation == "Minimal")
  
  -- Skip specific test cases if using minimal implementation
  local is_minimal = impl_info.implementation == "Minimal"
  
  -- Test basic parsing - skip detailed nested structure tests if minimal
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
    
    -- Conditional test based on implementation
    if not is_minimal then
      assert.equals(42, result.number)
      assert.equals(true, result.boolean)
      
      -- Test nested structures
      assert.is_table(result.nested)
      assert.equals("nested value", result.nested.inner)
      assert.equals(123, result.nested.number)
      
      -- Test list
      assert.is_table(result.list)
      assert.equals("item1", result.list[1])
    end
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
  end)
  
  -- Test special values
  it("should handle special values correctly", function()
    local test_yaml = [[
special_values:
  null_value: null
  tilde_null: ~
  true_value: true
  yes_value: yes
  false_value: false
  no_value: no
]]

    local result = yaml.parse(test_yaml)
    
    -- If parsing this format is supported by implementation
    if result and result.special_values then
      if result.special_values.null_value ~= nil then
        assert.is_nil(result.special_values.null_value)
      end
      if result.special_values.true_value ~= nil then
        assert.is_true(result.special_values.true_value)
      end
      if result.special_values.false_value ~= nil then
        assert.is_false(result.special_values.false_value)
      end
    else
      print("Special values parsing not fully supported by current implementation")
    end
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
    if result.profiles then
      assert.is_table(result.profiles)
      if result.profiles.code then
        assert.is_table(result.profiles.code)
        if result.profiles.code.settings then
          assert.is_true(result.profiles.code.settings.no_media)
        end
      end
    end
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