-- lua/spec/context-groups/utils/yaml_spec.lua
-- Tests for the YAML parser

local yaml = require("context-groups.utils.yaml")
local assert = require("luassert")

describe("YAML parser", function()
  -- Test basic parsing functionality
  it("should parse basic YAML correctly", function()
    local sample = [[
# This is a comment
key: value
number: 42
boolean: true
]]

    local result = yaml.eval(sample)
    assert.are.same({
      key = "value",
      number = 42,
      boolean = true
    }, result)
  end)

  -- Test nested structures
  it("should parse nested structures", function()
    local sample = [[
parent:
  child1: value1
  child2: value2
  nested:
    grandchild: value3
]]

    local result = yaml.eval(sample)
    assert.are.same({
      parent = {
        child1 = "value1",
        child2 = "value2",
        nested = {
          grandchild = "value3"
        }
      }
    }, result)
  end)

  -- Test arrays
  it("should parse arrays correctly", function()
    local sample = [[
items:
  - item1
  - item2
  - item3
mixed:
  - 42
  - true
  - value
]]

    local result = yaml.eval(sample)
    assert.are.same({
      items = {"item1", "item2", "item3"},
      mixed = {42, true, "value"}
    }, result)
  end)

  -- Test special values
  it("should handle special values correctly", function()
    local sample = [[
null_value: null
tilde_null: ~
true_value: true
yes_value: yes
false_value: false
no_value: no
]]

    local result = yaml.eval(sample)
    assert.is_nil(result.null_value)
    assert.is_nil(result.tilde_null)
    assert.is_true(result.true_value)
    assert.is_true(result.yes_value)
    assert.is_false(result.false_value)
    assert.is_false(result.no_value)
  end)

  -- Test complex documents
  it("should parse complex YAML documents", function()
    local sample = [[
---
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

    local result = yaml.eval(sample)
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

  -- Test encoding
  it("should encode YAML correctly", function()
    local data = {
      profiles = {
        code = {
          gitignores = {
            full_files = {".git", ".gitignore", ".llm-context/"}
          },
          settings = {
            no_media = true
          }
        }
      },
      templates = {
        context = "lc-context.j2"
      }
    }

    local yaml_string = yaml.encode(data)
    local parsed = yaml.eval(yaml_string)
    
    assert.is_string(yaml_string)
    assert.is_table(parsed)
    assert.is_table(parsed.profiles)
    assert.is_table(parsed.profiles.code)
    assert.is_table(parsed.profiles.code.gitignores)
    assert.is_table(parsed.profiles.code.gitignores.full_files)
    assert.is_true(#parsed.profiles.code.gitignores.full_files >= 3)
    assert.equals("lc-context.j2", parsed.templates.context)
    assert.is_true(parsed.profiles.code.settings.no_media)
  end)

  -- Test indentation parsing
  it("should handle indentation correctly", function()
    local sample = [[
level1:
  level2a:
    level3: value
  level2b: value
]]

    local result = yaml.eval(sample)
    assert.are.same({
      level1 = {
        level2a = {
          level3 = "value"
        },
        level2b = "value"
      }
    }, result)
  end)

  -- Test quoting
  it("should handle quoted strings", function()
    local sample = [[
single: 'single quoted'
double: "double quoted"
special: "contains: colon"
]]

    local result = yaml.eval(sample)
    assert.equals("single quoted", result.single)
    assert.equals("double quoted", result.double)
    assert.equals("contains: colon", result.special)
  end)
end)
