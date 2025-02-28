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
    assert.is_table(parsed.profiles)
    assert.is_table(parsed.profiles.code)
    assert.is_table(parsed.templates)
    assert.equals("lc-context.j2", parsed.templates.context)
    assert.equals(true, parsed.profiles.code.settings.no_media)
    assert.is_table(parsed.profiles.code.gitignores.full_files)
    assert.equals(".git", parsed.profiles.code.gitignores.full_files[1])
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
    assert.is_table(parsed.profiles)
    assert.is_table(parsed.profiles.code)
    assert.equals("lc-context.j2", parsed.templates.context)
    assert.equals(true, parsed.profiles.code.settings.no_media)
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
    assert.is_table(parsed.special_values)
    assert.is_nil(parsed.special_values.null_value)
    assert.is_nil(parsed.special_values.null_tilde)
    assert.is_true(parsed.special_values.true_value)
    assert.is_true(parsed.special_values.yes_value)
    assert.is_false(parsed.special_values.false_value)
    assert.is_false(parsed.special_values.no_value)
    assert.equals(42, parsed.special_values.number)
    assert.equals(3.14, parsed.special_values.float)
  end)
end)
