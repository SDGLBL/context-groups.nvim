-- lua/spec/context-groups/utils/toml_spec.lua

local TOML = require("context-groups.utils.toml")
local assert = require("luassert")

describe("TOML encoder", function()
  -- 测试基本数据类型编码
  it("should encode basic data types correctly", function()
    local data = {
      string_val = "hello",
      number_val = 42,
      bool_val = true,
      float_val = 3.14,
    }

    local encoded = TOML.encode(data)
    local decoded = TOML.parse(encoded)

    assert.are.same(data, decoded)
  end)

  -- 测试字符串数组编码
  it("should encode string arrays correctly", function()
    local data = {
      fruits = { "apple", "banana", "orange" },
    }

    local encoded = TOML.encode(data)
    assert.matches('fruits = %[\n"apple",\n"banana",\n"orange",\n%]', encoded)

    local decoded = TOML.parse(encoded)
    assert.are.same(data, decoded)
  end)

  -- 测试混合类型数组编码
  it("should encode mixed type arrays correctly", function()
    local data = {
      mixed = { 1, "two", true, 4.5 },
    }

    local encoded = TOML.encode(data)
    local decoded = TOML.parse(encoded)

    assert.are.same(data, decoded)
  end)

  -- 测试嵌套表编码
  it("should encode nested tables correctly", function()
    local data = {
      database = {
        ports = { 8000, 8001, 8002 },
        hosts = { "localhost", "127.0.0.1" },
        connection = {
          max_size = 100,
          timeout = 30,
        },
      },
    }

    local encoded = TOML.encode(data)
    local decoded = TOML.parse(encoded)

    assert.are.same(data, decoded)
  end)

  -- 测试 llm-context 特定配置格式
  it("should encode llm-context config correctly", function()
    local data = {
      templates = {
        context = "lc-context.j2",
        files = "lc-files.j2",
      },
      profiles = {
        code = {
          gitignores = {
            full_files = { ".git", ".gitignore", "*.lock" },
            outline_files = { ".git", ".gitignore", "*.lock" },
          },
          settings = {
            no_media = true,
            with_user_notes = false,
          },
          only_include = {
            full_files = { "**/*" },
            outline_files = { "**/*" },
          },
        },
      },
    }

    local encoded = TOML.encode(data)

    -- 验证字符串数组格式
    assert.matches('full_files = %[\n"%.git",\n"%.gitignore",\n"%*%.lock",\n%]', encoded)
    assert.matches('outline_files = %[\n"%.git",\n"%.gitignore",\n"%*%.lock",\n%]', encoded)

    local decoded = TOML.parse(encoded)
    assert.are.same(data, decoded)
  end)

  -- 测试特殊字符处理
  it("should handle special characters in strings correctly", function()
    local data = {
      paths = {
        "C:\\Program Files\\App",
        "/usr/local/bin",
        "file with spaces",
        "quotes\"and'stuff",
      },
    }

    local encoded = TOML.encode(data)
    local decoded = TOML.parse(encoded)

    assert.are.same(data, decoded)
  end)

  -- 测试空数组和表
  it("should handle empty arrays and tables correctly", function()
    local data = {
      empty_array = {},
      empty_table = {
        nested_empty = {},
      },
    }

    local encoded = TOML.encode(data)
    local decoded = TOML.parse(encoded)

    assert.are.same(data, decoded)
  end)

  -- 测试多行字符串
  it("should handle multiline strings correctly", function()
    local data = {
      text = "line1\nline2\nline3",
    }

    local encoded = TOML.encode(data)
    local decoded = TOML.parse(encoded)

    assert.are.same(data, decoded)
  end)

  -- 测试数组中的空值处理
  it("should handle nil values in arrays correctly", function()
    local array_with_nils = { "first", nil, "third" }
    local data = {
      array = array_with_nils,
    }

    local encoded = TOML.encode(data)
    local decoded = TOML.parse(encoded)

    -- 在 TOML 中，数组不应该包含空值
    assert.are.same({ array = { "first", "third" } }, decoded)
  end)

  -- 测试重复键检测
  it("should handle duplicate keys according to spec", function()
    local toml_str = [[
[fruit]
name = "apple"

[fruit]
name = "banana"
    ]]

    assert.has_error(function()
      TOML.parse(toml_str)
    end, "TOML: Cannot redefine table")
  end)
end)
