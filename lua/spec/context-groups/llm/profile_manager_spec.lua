-- lua/spec/context-groups/llm/profile_manager_spec.lua
-- Test the internal ProfileManager implementation

local LLMContext = require("context-groups.llm")
local utils = require("context-groups.utils")
local assert = require("luassert")

describe("ProfileManager", function()
  local test_root = "/tmp/test-profile-manager"
  local profile_manager
  local llm_context
  
  before_each(function()
    -- Set up test environment
    vim.fn.mkdir(test_root .. "/.llm-context", "p")
    
    -- Create minimal config file
    local config_content = [[
[templates]
context = "lc-context.j2"
files = "lc-files.j2"

[profiles.code]
[profiles.code.gitignores]
full_files = [
  ".git",
  ".gitignore"
]

[profiles.code.settings]
no_media = true

[profiles.code.only-include]
full_files = ["**/*"]
]]
    
    vim.fn.writefile(vim.split(config_content, "\n"), test_root .. "/.llm-context/config.toml")
    
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
    -- Create new config to write
    local config = profile_manager:read_config()
    
    -- Add new profile
    config.profiles.test = {
      gitignores = {
        full_files = { ".git" },
        outline_files = { ".git" }
      },
      settings = {
        no_media = true
      },
      ["only-include"] = {
        full_files = { "**/*" }
      }
    }
    
    -- Write config
    local success = profile_manager:write_config(config)
    assert.is_true(success)
    
    -- Read back and verify
    local new_config = profile_manager:read_config()
    assert.is_table(new_config.profiles.test)
    assert.equals(true, new_config.profiles.test.settings.no_media)
  end)
end)
