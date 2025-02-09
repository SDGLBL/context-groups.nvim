---@class LLMContextProfile
---@field gitignores table<string, string[]> Additional file patterns to ignore
---@field settings table<string, any> Profile settings
---@field only_include table<string, string[]> Optional file patterns to include

---@class LLMContext
---@field private config_path string Path to llm-context config file
---@field private ctx_file string Path to current context file
---@field private profiles table<string, LLMContextProfile> Cached profiles
local LLMContext = {}
LLMContext.__index = LLMContext

-- Constants
local CONFIG_DIR = ".llm-context"
local CONFIG_FILE = "config.toml"
local CURR_CTX_FILE = "curr_ctx.toml"
local TOML = require("context-groups.utils.toml")

---Create new LLMContext instance for a project
---@param root string Project root directory
---@return LLMContext
function LLMContext.new(root)
  local self = setmetatable({}, LLMContext)
  self.config_path = root .. "/" .. CONFIG_DIR .. "/" .. CONFIG_FILE
  self.ctx_file = root .. "/" .. CONFIG_DIR .. "/" .. CURR_CTX_FILE
  self.profiles = {}
  return self
end

---Check if llm-context is initialized in the project
---@return boolean
function LLMContext:is_initialized()
  return vim.fn.filereadable(self.config_path) == 1
end

---Initialize llm-context in the project
---@return boolean success
function LLMContext:initialize()
  -- Check if already initialized
  if self:is_initialized() then
    return true
  end

  -- Create .llm-context directory
  local config_dir = vim.fn.fnamemodify(self.config_path, ":h")
  if vim.fn.mkdir(config_dir, "p") ~= 1 then
    vim.notify("Failed to create llm-context config directory", vim.log.levels.ERROR)
    return false
  end

  -- Run lc-init
  local init_cmd = "cd " .. vim.fn.shellescape(vim.fn.fnamemodify(self.config_path, ":h:h")) .. " && lc-init"
  local init_result = vim.fn.system(init_cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to initialize llm-context: " .. init_result, vim.log.levels.ERROR)
    return false
  end

  return true
end

---Read and parse TOML configuration
---@return table? config Configuration table or nil on error
function LLMContext:read_config()
  if not self:is_initialized() then
    return nil
  end

  local content = vim.fn.readfile(self.config_path)
  if not content then
    return nil
  end

  -- Join lines for TOML parsing
  local toml_content = table.concat(content, "\n")
  local ok, parsed = pcall(TOML.parse, toml_content)
  if not ok then
    vim.notify("Failed to parse TOML config: " .. tostring(parsed), vim.log.levels.ERROR)
    return nil
  end
  return parsed
end

---Write TOML configuration
---@param config table Configuration to write
---@return boolean success
function LLMContext:write_config(config)
  if not self:is_initialized() then
    return false
  end

  -- Encode to TOML and split into lines
  local encoded = TOML.encode(config)
  local lines = vim.split(encoded, "\n")
  return vim.fn.writefile(lines, self.config_path) == 0
end

---Get available profiles
---@return string[] profile_names List of profile names
function LLMContext:get_profiles()
  local config = self:read_config()
  if not config or not config.profiles then
    return {}
  end

  local profiles = {}
  for name, _ in pairs(config.profiles) do
    table.insert(profiles, name)
  end

  return profiles
end

---Switch to profile
---@param profile string Profile name
---@return boolean success
function LLMContext:switch_profile(profile)
  -- Run lc-set-profile command
  local cmd = string.format(
    "cd %s && lc-set-profile %s",
    vim.fn.shellescape(vim.fn.fnamemodify(self.config_path, ":h:h")),
    vim.fn.shellescape(profile)
  )

  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to switch profile: " .. result, vim.log.levels.ERROR)
    return false
  end

  return true
end

---Create new profile from current context group
---@param name string Profile name
---@param opts table Profile options
---@return boolean success
function LLMContext:create_profile(name, opts)
  local config = self:read_config()
  if not config then
    return false
  end

  vim.notify("context_group: " .. vim.inspect(config), vim.log.levels.INFO)

  -- Create profile configuration
  config.profiles = config.profiles or {}

  config.profiles[name] = {
    gitignores = opts.gitignores or {},
    settings = opts.settings or {},
    only_include = opts.only_include or {},
  }

  return self:write_config(config)
end

---Update files in current context
---@return boolean success
function LLMContext:update_files()
  -- Run lc-sel-files command
  local cmd = string.format("cd %s && lc-sel-files", vim.fn.shellescape(vim.fn.fnamemodify(self.config_path, ":h:h")))

  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to update files: " .. result, vim.log.levels.ERROR)
    return false
  end

  return true
end

---Reads and parses the llm-context current context file
---@param self LLMContext
---@return string[] files List of file paths
function LLMContext:get_context_files()
  -- Check if context file exists
  if not vim.fn.filereadable(self.ctx_file) then
    return {}
  end

  -- Read the file content
  local content = vim.fn.readfile(self.ctx_file)
  if not content then
    return {}
  end

  -- Join the lines and parse as TOML
  local toml_content = table.concat(content, "\n")
  local ok, parsed = pcall(TOML.parse, toml_content)
  if not ok or not parsed then
    vim.notify("Failed to parse llm-context current context file", vim.log.levels.ERROR)
    return {}
  end

  -- Extract paths from curr_ctx.toml structure
  local files = {}
  local function extract_paths(section)
    if not section then
      return
    end

    -- Handle files array
    if vim.tbl_islist(section) then
      for _, entry in ipairs(section) do
        if type(entry) == "table" and entry.path then
          table.insert(files, entry.path)
        end
      end
      return
    end

    -- Handle files table with path fields
    if type(section) == "table" then
      -- Check for direct path field
      if section.path then
        table.insert(files, section.path)
      end

      -- Check for nested structures
      for _, value in pairs(section) do
        if type(value) == "table" then
          extract_paths(value)
        end
      end
    end
  end

  -- Extract from both files and outlines sections if they exist
  if parsed.files then
    extract_paths(parsed.files)
  end
  if parsed.outlines then
    extract_paths(parsed.outlines)
  end

  -- Remove duplicates while preserving order
  local seen = {}
  local unique_files = {}
  for _, file in ipairs(files) do
    if not seen[file] then
      seen[file] = true
      table.insert(unique_files, file)
    end
  end

  return unique_files
end

return LLMContext
