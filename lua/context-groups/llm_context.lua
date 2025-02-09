-- lua/context-groups/llm_context.lua

---@class LLMContext
---@field private root string Project root directory
---@field public profile_manager ProfileManager Profile manager instance
local LLMContext = {}
LLMContext.__index = LLMContext

-- Constants
local CONFIG_DIR = ".llm-context"
local CONFIG_FILE = "config.toml"

---Create new LLMContext instance for a project
---@param root string Project root directory
---@return LLMContext
function LLMContext.new(root)
  local self = setmetatable({}, LLMContext)
  self.root = root

  -- Initialize profile manager
  local ProfileManager = require("context-groups.llm_context.profile")
  self.profile_manager = ProfileManager.new(root)

  return self
end

---Check if llm-context is initialized in the project
---@return boolean
function LLMContext:is_initialized()
  return vim.fn.filereadable(self.root .. "/" .. CONFIG_DIR .. "/" .. CONFIG_FILE) == 1
end

---Initialize llm-context in the project
---@return boolean success
function LLMContext:initialize()
  -- Check if already initialized
  if self:is_initialized() then
    return true
  end

  -- Create .llm-context directory
  local config_dir = self.root .. "/" .. CONFIG_DIR
  if vim.fn.mkdir(config_dir, "p") ~= 1 then
    vim.notify("Failed to create llm-context config directory", vim.log.levels.ERROR)
    return false
  end

  -- Run lc-init
  local init_cmd = "cd " .. vim.fn.shellescape(self.root) .. " && lc-init"
  local init_result = vim.fn.system(init_cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to initialize llm-context: " .. init_result, vim.log.levels.ERROR)
    return false
  end

  return true
end

---Get available profiles
---@return string[] profile_names List of profile names
function LLMContext:get_profiles()
  return self.profile_manager:get_profiles()
end

---Get current active profile
---@return string? profile_name Current profile name
function LLMContext:get_current_profile()
  return self.profile_manager:get_current_profile()
end

---Switch to profile
---@param profile string Profile name
---@return boolean success
function LLMContext:switch_profile(profile)
  return self.profile_manager:switch_profile(profile)
end

---Create new profile
---@param name string Profile name
---@param opts table Profile options
---@return boolean success
function LLMContext:create_profile(name, opts)
  return self.profile_manager:create_profile(name, opts)
end

---Create profile from current context group
---@param name string Profile name
---@param context_files string[] Current context files
---@return boolean success
function LLMContext:create_profile_from_context(name, context_files)
  return self.profile_manager:create_profile_from_context(name, context_files)
end

---Update files in current context
---@return boolean success
function LLMContext:update_files()
  return self.profile_manager:update_files()
end

-- Update
---@param profile string? Profile name
function LLMContext:update_files_with_buffer(profile)
  return self.profile_manager:update_profile_with_buffers(profile)
end

---Get current context files
---@return string[] files List of file paths
function LLMContext:get_context_files()
  return self.profile_manager:get_context_files()
end

return LLMContext
