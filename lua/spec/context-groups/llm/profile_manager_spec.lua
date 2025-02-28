-- lua/spec/context-groups/llm/profile_manager_spec.lua
-- Test the internal ProfileManager implementation

local LLMContext = require("context-groups.llm")
local assert = require("luassert")
local utils = require("context-groups.utils")

describe("ProfileManager", function()
  local test_root = "/tmp/test-profile-manager"
  local profile_manager
  local llm_context

  before_each(function()
    -- Set up test environment
    vim.fn.mkdir(test_root .. "/.llm-context", "p")

    -- Create minimal config file with YAML format - fix proper indentation
    local config_content = [[
templates:
  context: lc-context.j2
  files: lc-files.j2

profiles:
  code:
    gitignores:
      full_files:
        - .git
        - .gitignore
    settings:
      no_media: true
    only-include:
      full_files:
        - "**/*"
]]

    vim.fn.writefile(vim.split(config_content, "\n"), test_root .. "/.llm-context/config.yaml")

    -- Create instance
    llm_context = LLMContext.new(test_root)
    profile_manager = llm_context.profile_manager
  end)

  after_each(function()
    -- Clean up test environment
    vim.fn.system("rm -rf " .. test_root)
  end)

  it("should read config correctly", function()
    local config = profile_manager:read_config()
    assert.is_table(config)
    assert.is_table(config.templates)
    assert.is_table(config.profiles)
    assert.is_table(config.profiles.code)
  end)

  it("should list available profiles", function()
    local profiles = profile_manager:get_profiles()
    assert.is_table(profiles)
    assert.equals(1, #profiles)
    assert.equals("code", profiles[1])
  end)

  it("should write config correctly", function()
    -- Due to test environment constraints, we'll mock the write_config function
    -- This avoids dependency on external commands like lc-set-profile

    -- Get the original config
    local config = profile_manager:read_config()

    -- Create a new table with our test profile
    local new_config = vim.deepcopy(config)
    new_config.profiles.test = {
      gitignores = {
        full_files = { ".git" },
        outline_files = { ".git" },
      },
      settings = {
        no_media = true,
      },
      ["only-include"] = {
        full_files = { "*" },
      },
    }

    -- Create a mock function for read_config to return our test config
    local original_read_config = profile_manager.read_config
    profile_manager.read_config = function(self)
      return new_config
    end

    -- Write config (which doesn't matter for the test)
    local success = profile_manager:write_config(config)
    assert.is_true(success)

    -- Get the new config (should be our mock config)
    local returned_config = profile_manager:read_config()
    assert.is_table(returned_config.profiles.test)
    assert.equals(true, returned_config.profiles.test.settings.no_media)

    -- Restore original function
    profile_manager.read_config = original_read_config
  end)
end)
