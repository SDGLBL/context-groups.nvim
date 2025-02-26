-- lua/spec/context-groups/llm/init_spec.lua
local LLMContext = require("context-groups.llm")
local assert = require("luassert")
local utils = require("context-groups.utils")

describe("LLMContext", function()
  local test_root = "/tmp/test-context-groups"
  local llm_context

  before_each(function()
    -- Set up test environment
    vim.fn.mkdir(test_root .. "/.llm-context", "p")
    llm_context = LLMContext.new(test_root)

    -- Create stub files for testing
    vim.fn.writefile({
      '__info__ = "Test config file"',
      "",
      "[templates]",
      'context = "lc-context.j2"',
      'files = "lc-files.j2"',
      "",
      "[profiles.code]",
      "[profiles.code.gitignores]",
      "full_files = [",
      '  ".git",',
      '  ".gitignore",',
      "]",
      "[profiles.code.settings]",
      "no_media = true",
    }, test_root .. "/.llm-context/config.toml")
  end)

  after_each(function()
    -- Clean up test environment
    vim.fn.system("rm -rf " .. test_root)
  end)

  it("should detect initialization status correctly", function()
    assert.is_true(llm_context:is_initialized())

    -- Test with missing config
    vim.fn.system("rm " .. test_root .. "/.llm-context/config.toml")
    assert.is_false(llm_context:is_initialized())
  end)

  it("should have profile manager", function()
    assert.is_table(llm_context.profile_manager)
  end)

  it("should get available profiles", function()
    local profiles = llm_context:get_profiles()
    assert.is_table(profiles)
  end)
end)
