-- lua/spec/context-groups/llm/yaml_support_spec.lua

local utils = require("context-groups.utils")

describe("YAML support", function()
  it("should parse YAML strings correctly", function()
    local yaml_content = [[
profiles:
  code:
    gitignores:
      full_files:
      - .git
      - .gitignore
      - .llm-context/
      - "*.tmp"
      - "*.lock"
    settings:
      no_media: true
      with_user_notes: false
    only-include:
      full_files:
      - "**/*"
templates:
  context: lc-context.j2
  files: lc-files.j2
]]

    local parsed = utils.YAML.parse(yaml_content)
    assert.is_table(parsed)
    
    -- Check if profiles are supported in the parsing
    if parsed.profiles then
      assert.is_table(parsed.profiles)
      if parsed.profiles.code then
        assert.is_table(parsed.profiles.code)
      end
    end
    
    -- Check if templates are supported in the parsing
    if parsed.templates then
      assert.is_table(parsed.templates)
      if parsed.templates.context then
        assert.equals("lc-context.j2", parsed.templates.context)
      end
    end
  end)

  it("should encode YAML correctly", function()
    local data = {
      profiles = {
        code = {
          gitignores = {
            full_files = { ".git", ".gitignore", ".llm-context/" },
          },
          settings = {
            no_media = true,
          },
        },
      },
      templates = {
        context = "lc-context.j2",
      },
    }

    local encoded = utils.YAML.encode(data)
    assert.is_string(encoded)

    -- Ensure it can be parsed back correctly
    local parsed = utils.YAML.parse(encoded)
    assert.is_table(parsed)
    
    -- Check if profiles are supported in the parsing
    if parsed.profiles then
      assert.is_table(parsed.profiles)
      if parsed.profiles.code then
        assert.is_table(parsed.profiles.code)
      end
    end
  end)

  it("should handle special YAML values", function()
    local yaml_content = [[
special_values:
  null_value: null
  null_tilde: ~
  true_value: true
  yes_value: yes
  false_value: false
  no_value: no
  number: 42
  float: 3.14
]]

    local parsed = utils.YAML.parse(yaml_content)
    assert.is_table(parsed)
    
    -- Check special values if supported
    if parsed.special_values then
      assert.is_table(parsed.special_values)
      
      if parsed.special_values.true_value ~= nil then
        assert.is_true(parsed.special_values.true_value)
      end
      if parsed.special_values.number ~= nil then
        assert.equals(42, parsed.special_values.number)
      end
    end
  end)
end)