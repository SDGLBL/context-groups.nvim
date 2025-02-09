-- lua/context-groups/llm_context/profile.lua

---@class Profile
---@field gitignores ProfileGitignores Gitignore patterns
---@field settings ProfileSettings Profile settings
---@field only-include ProfileIncludes File include patterns
---@field base? string Base profile name for inheritance
---@field prompt? string Path to prompt template

---@class ProfileSettings
---@field no_media boolean Exclude media files
---@field with_user_notes boolean Include user notes
---@field with_prompt boolean Include prompts
---@field context_file string? Save context to file

---@class ProfileGitignores
---@field full_files string[] Files to exclude from full content
---@field outline_files string[] Files to exclude from outlines

---@class ProfileIncludes
---@field full_files string[] Files to include in full content
---@field outline_files string[] Files to include in outlines

---@class ProfileManager
---@field private config_path string Path to config file
---@field private ctx_file string Path to current context file
---@field private profiles table<string, Profile> Cached profiles
---@field private current_profile string? Current active profile
local ProfileManager = {}
ProfileManager.__index = ProfileManager

local TOML = require("context-groups.utils.toml")

-- Get all open buffer file paths
---@return string[] file_paths
function ProfileManager:get_open_buffer_files()
  local files = {}
  local seen = {}
  local core = require("context-groups.core")

  -- 获取当前打开的文件
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    -- 只包含正常的文件缓冲区
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" then
      local path = vim.api.nvim_buf_get_name(bufnr)
      if path and path ~= "" and vim.fn.filereadable(path) == 1 then
        -- 转换为相对路径
        local root_path = vim.fn.fnamemodify(self.config_path, ":h:h")
        path = vim.fn.fnamemodify(path, ":p")
        if vim.startswith(path, root_path) then
          path = path:sub(#root_path + 2) -- +2 to remove the trailing slash
          seen[path] = true
          table.insert(files, path)

          -- 获取这个 buffer 的上下文组文件
          local context_files = core.get_context_files(bufnr, { relative = true })
          for _, context_file in ipairs(context_files) do
            if not seen[context_file] then
              seen[context_file] = true
              table.insert(files, context_file)
            end
          end
        end
      end
    end
  end

  return files
end

-- Update profile with buffer files
---@param profile_name string Profile name
---@return boolean success
function ProfileManager:update_profile_with_buffers(profile_name)
  local config = self:read_config()
  if not config or not config.profiles or not config.profiles[profile_name] then
    return false
  end

  -- Get current buffer files including dependencies
  local buffer_files = self:get_open_buffer_files()
  if #buffer_files == 0 then
    return true -- No files to add
  end

  -- Update profile's only_include patterns
  ---@type Profile
  local profile = config.profiles[profile_name]

  -- Remove duplicates while preserving order
  local function deduplicate(list)
    local seen = {}
    local result = {}
    for _, item in ipairs(list) do
      if not seen[item] then
        seen[item] = true
        table.insert(result, item)
      end
    end
    return result
  end

  profile["only-include"].full_files = deduplicate(buffer_files)
  profile["only-include"].outline_files = deduplicate(buffer_files)

  -- Write updated configuration
  return self:write_config(config)
end

-- Create new ProfileManager instance
---@param root string Project root directory
---@return ProfileManager
function ProfileManager.new(root)
  local self = setmetatable({}, ProfileManager)
  self.config_path = root .. "/.llm-context/config.toml"
  self.ctx_file = root .. "/.llm-context/curr_ctx.toml"
  self.profiles = {}
  self.current_profile = nil

  -- Try to activate code profile by default if initialized
  if self:is_initialized() then
    local config = self:read_config()
    if config and config.profiles and config.profiles.code then
      self:switch_profile("code")
      -- Add current buffer files to code profile
      self:update_profile_with_buffers("code")
    end
  end

  return self
end

-- Check if initialized
---@return boolean
function ProfileManager:is_initialized()
  return vim.fn.filereadable(self.config_path) == 1
end

-- Read and parse TOML configuration
---@return table? config
function ProfileManager:read_config()
  if not self:is_initialized() then
    return nil
  end

  local content = vim.fn.readfile(self.config_path)
  if not content then
    return nil
  end

  local toml_content = table.concat(content, "\n")
  local ok, parsed = pcall(TOML.parse, toml_content)
  if not ok then
    vim.notify("Failed to parse TOML config: " .. tostring(parsed), vim.log.levels.ERROR)
    return nil
  end
  return parsed
end

-- Write TOML configuration
---@param config table Configuration to write
---@return boolean success
function ProfileManager:write_config(config)
  local encoded = TOML.encode(config)
  local lines = vim.split(encoded, "\n")
  return vim.fn.writefile(lines, self.config_path) == 0
end

-- Get available profiles
---@return string[] profile_names
function ProfileManager:get_profiles()
  local config = self:read_config()
  if not config or not config.profiles then
    return {}
  end

  local profiles = {}
  for name, _ in pairs(config.profiles) do
    table.insert(profiles, name)
  end
  table.sort(profiles)
  return profiles
end

-- Get current active profile
---@return string? profile_name
function ProfileManager:get_current_profile()
  return self.current_profile
end

-- Switch to profile
---@param profile string Profile name
---@return boolean success
function ProfileManager:switch_profile(profile)
  local config = self:read_config()
  if not config or not config.profiles[profile] then
    vim.notify("Profile '" .. profile .. "' not found", vim.log.levels.ERROR)
    return false
  end

  -- Update profile with current buffer files before switching
  self:update_profile_with_buffers(profile)

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

  self.current_profile = profile

  -- Update files after profile switch
  self:update_files()
  return true
end

-- Create new profile
---@param name string Profile name
---@param opts table Profile options
---@return boolean success
function ProfileManager:create_profile(name, opts)
  local config = self:read_config()
  if not config then
    return false
  end

  -- Check if profile already exists
  if config.profiles and config.profiles[name] then
    vim.notify("Profile '" .. name .. "' already exists", vim.log.levels.ERROR)
    return false
  end

  -- Create profile configuration
  config.profiles = config.profiles or {}
  config.profiles[name] = {
    gitignores = opts.gitignores or {
      full_files = { ".git", ".gitignore", ".llm-context/", "*.lock" },
      outline_files = { ".git", ".gitignore", ".llm-context/", "*.lock" },
    },
    settings = opts.settings or {
      no_media = true,
      with_user_notes = false,
      with_prompt = false,
    },
    ["only-include"] = opts.only_include or {
      full_files = { "**/*" },
      outline_files = { "**/*" },
    },
  }

  -- Write updated configuration
  if not self:write_config(config) then
    return false
  end

  -- Add current buffer files to the new profile
  self:update_profile_with_buffers(name)

  -- Switch to new profile
  return self:switch_profile(name)
end

-- Create profile from current context group
---@param name string Profile name
---@param context_files string[] Current context files
---@return boolean success
function ProfileManager:create_profile_from_context(name, context_files)
  -- Get buffer files to include
  local buffer_files = self:get_open_buffer_files()

  -- Combine context files and buffer files, removing duplicates
  local seen = {}
  local all_files = {}

  local function add_file(file)
    if not seen[file] then
      seen[file] = true
      table.insert(all_files, file)
    end
  end

  for _, file in ipairs(context_files) do
    add_file(file)
  end

  for _, file in ipairs(buffer_files) do
    add_file(file)
  end

  -- Create profile with all files
  return self:create_profile(name, {
    only_include = {
      full_files = all_files,
      outline_files = all_files,
    },
  })
end

-- Update files in current context
---@return boolean success
function ProfileManager:update_files()
  local cmd = string.format("cd %s && lc-sel-files", vim.fn.shellescape(vim.fn.fnamemodify(self.config_path, ":h:h")))

  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to update files: " .. result, vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Get current context files
---@return string[] files
function ProfileManager:get_context_files()
  if vim.fn.filereadable(self.ctx_file) ~= 1 then
    return {}
  end

  local content = vim.fn.readfile(self.ctx_file)
  if not content then
    return {}
  end

  local toml_content = table.concat(content, "\n")
  local ok, parsed = pcall(TOML.parse, toml_content)
  if not ok or not parsed then
    vim.notify("Failed to parse context file", vim.log.levels.ERROR)
    return {}
  end

  local files = {}
  local function extract_paths(section)
    if not section then
      return
    end
    if vim.tbl_islist(section) then
      for _, entry in ipairs(section) do
        if type(entry) == "table" and entry.path then
          table.insert(files, entry.path)
        end
      end
    elseif type(section) == "table" then
      for _, value in pairs(section) do
        if type(value) == "table" then
          extract_paths(value)
        end
      end
    end
  end

  -- Extract from both files and outlines sections
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

return ProfileManager
