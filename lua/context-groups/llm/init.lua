-- lua/context-groups/llm/init.lua
-- Consolidated LLM integration functionality

local core = require("context-groups.core")
local utils = require("context-groups.utils")

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

---@class LLMContext
---@field private root string Project root directory
---@field profile_manager ProfileManager Profile manager instance
local LLMContext = {}
LLMContext.__index = LLMContext

-- Constants
local CONFIG_DIR = ".llm-context"
local CONFIG_FILE = "config.yaml" -- Default config format

-- ProfileManager implementation (from llm_context/profile.lua)
---@class ProfileManager
---@field private config_path string Path to config file
---@field private ctx_file string Path to current context file
---@field private profiles table<string, Profile> Cached profiles
---@field private current_profile string? Current active profile
local ProfileManager = {}
ProfileManager.__index = ProfileManager

-- Create new ProfileManager instance
---@param root string Project root directory
---@return ProfileManager
function ProfileManager.new(root)
  local self = setmetatable({}, ProfileManager)
  self.root = root
  self.config_dir = root .. "/" .. CONFIG_DIR
  self.config_path = self.config_dir .. "/" .. CONFIG_FILE
  self.ctx_file = self.config_dir .. "/curr_ctx.toml" -- Context state file
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

-- Read and parse configuration (YAML or TOML)
---@return table? config
function ProfileManager:read_config()
  if not self:is_initialized() then
    return nil
  end

  local content = utils.read_file_content(self.config_path)
  if not content then
    return nil
  end

  -- Parse YAML
  local parsed = utils.YAML.parse(content)
  if not parsed then
    vim.notify("Failed to parse YAML config", vim.log.levels.ERROR)
    return nil
  end
  return parsed
end

-- Write configuration (YAML or TOML)
---@param config table Configuration to write
---@return boolean success
function ProfileManager:write_config(config)
  -- Encode as YAML
  local encoded = utils.YAML.encode(config)
  return utils.write_file_content(self.config_path, encoded)
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

  -- Set base to "code" by default if it exists and not explicitly provided
  local use_base = opts.base
  if use_base == nil and config.profiles.code then
    use_base = "code"
  end

  config.profiles[name] = {
    -- Add base field to inherit from code profile
    base = use_base,
    -- Only include additional configurations that differ from base profile
    settings = opts.settings or {
      no_media = true,
      with_user_notes = false,
      with_prompt = false,
    },
    -- Keep gitignores and only-include if explicitly provided
    -- otherwise they will be inherited from the base profile
  }

  -- Add gitignores and only-include only if explicitly provided
  -- or if no base profile is used
  if not use_base or opts.gitignores then
    config.profiles[name].gitignores = opts.gitignores
      or {
        full_files = {
          ".git",
          ".gitignore",
          ".llm-context/",
          "rust/target/*",
          "*.tmp",
          "*.lock",
          "package-lock.json",
          "yarn.lock",
          "pnpm-lock.yaml",
          "go.sum",
          "elm-stuff",
          "LICENSE",
          "CHANGELOG.md",
          "README.md",
          ".env",
          ".dockerignore",
          "Dockerfile",
          "docker-compose.yml",
          "*.log",
          "*.svg",
          "*.png",
          "*.jpg",
          "*.jpeg",
          "*.gif",
          "*.ico",
          "*.woff",
          "*.woff2",
          "*.eot",
          "*.ttf",
          "*.map",
        },
        outline_files = {
          ".git",
          ".gitignore",
          ".llm-context/",
          "rust/target/*",
          "*.tmp",
          "*.lock",
          "package-lock.json",
          "yarn.lock",
          "pnpm-lock.yaml",
          "go.sum",
          "elm-stuff",
          "LICENSE",
          "CHANGELOG.md",
          "README.md",
          ".env",
          ".dockerignore",
          "Dockerfile",
          "docker-compose.yml",
          "*.log",
          "*.svg",
          "*.png",
          "*.jpg",
          "*.jpeg",
          "*.gif",
          "*.ico",
          "*.woff",
          "*.woff2",
          "*.eot",
          "*.ttf",
          "*.map",
        },
      }
  end

  if not use_base or opts.only_include then
    config.profiles[name]["only-include"] = opts.only_include
      or {
        full_files = { "**/*" },
        outline_files = { "**/*" },
      }
  end

  -- Write updated configuration
  if not self:write_config(config) then
    return false
  end

  -- Add current buffer files to the new profile
  self:update_profile_with_buffers(name)

  -- Switch to new profile
  return self:switch_profile(name)
end

-- Get all open buffer file paths
---@return string[] file_paths
function ProfileManager:get_open_buffer_files()
  local files = {}
  local seen = {}
  local context_core = require("context-groups.core")

  -- Get currently open files
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    -- Only include normal file buffers
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" then
      local path = vim.api.nvim_buf_get_name(bufnr)
      if path and path ~= "" and vim.fn.filereadable(path) == 1 then
        -- Convert to relative path
        local root_path = vim.fn.fnamemodify(self.config_path, ":h:h")
        path = vim.fn.fnamemodify(path, ":p")
        if vim.startswith(path, root_path) then
          path = path:sub(#root_path + 2) -- +2 to remove the trailing slash
          seen[path] = true
          table.insert(files, path)

          -- Get context group files for this buffer
          local context_files = context_core.get_context_files(bufnr, { relative = true })
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

  -- Create profile with all files and use 'code' as the base
  return self:create_profile(name, {
    base = "code", -- Explicitly set base to code
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

  local content = utils.read_file_content(self.ctx_file)
  if not content then
    return {}
  end

  local ok, parsed = pcall(utils.TOML.parse, content)
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

---Update profile with specific file lists
---@param profile_name string? Profile name
---@param added string[] Files to add
---@param removed string[] Files to remove
---@return boolean success
function ProfileManager:update_profile_with_file_lists(profile_name, added, removed)
  profile_name = profile_name or self.current_profile

  if not profile_name then
    vim.notify("No profile specified", vim.log.levels.ERROR)
    return false
  end

  local config = self:read_config()
  if not config or not config.profiles or not config.profiles[profile_name] then
    return false
  end

  -- Get current profile
  ---@type Profile
  local profile = config.profiles[profile_name]

  -- Current file lists
  local current_files = profile["only-include"].full_files or {}

  -- Create new file lists removing deleted files and adding new ones
  local new_files = {}
  local seen = {}

  -- Helper to add file if not seen
  local function add_file(file)
    if not seen[file] then
      seen[file] = true
      table.insert(new_files, file)
    end
  end

  -- Add current files that weren't removed
  for _, file in ipairs(current_files) do
    if not vim.tbl_contains(removed, file) then
      add_file(file)
    end
  end

  -- Add new files
  for _, file in ipairs(added) do
    add_file(file)
  end

  -- Update profile's only_include patterns
  profile["only-include"].full_files = new_files
  profile["only-include"].outline_files = new_files

  -- Write updated configuration
  return self:write_config(config)
end

-- Update profile with buffer files
---@param profile_name string? Profile name
---@return boolean success
function ProfileManager:update_profile_with_buffers(profile_name)
  -- Get current buffer files
  local buffer_files = self:get_open_buffer_files()
  if #buffer_files == 0 then
    return true -- No files to add
  end

  -- Get current profile
  profile_name = profile_name or self.current_profile
  if not profile_name then
    vim.notify("No profile specified", vim.log.levels.ERROR)
    return false
  end

  local config = self:read_config()
  if not config or not config.profiles or not config.profiles[profile_name] then
    return false
  end

  -- Get current files
  local current_files = config.profiles[profile_name]["only-include"].full_files or {}

  -- Calculate differences
  local added = {}
  local removed = {}

  -- Find new files to add
  for _, file in ipairs(buffer_files) do
    if not vim.tbl_contains(current_files, file) then
      table.insert(added, file)
    end
  end

  -- Find files to remove
  for _, file in ipairs(current_files) do
    if not vim.tbl_contains(buffer_files, file) then
      table.insert(removed, file)
    end
  end

  -- Update profile with calculated differences
  return self:update_profile_with_file_lists(profile_name, added, removed)
end

---Create new LLMContext instance for a project
---@param root string Project root directory
---@return LLMContext
function LLMContext.new(root)
  local self = setmetatable({}, LLMContext)
  self.root = root
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

  -- Try to run lc-init command first
  local init_cmd = "cd " .. vim.fn.shellescape(self.root) .. " && lc-init"
  local init_result = vim.fn.system(init_cmd)

  -- Check if initialization was successful
  if vim.v.shell_error == 0 then
    return true
  else
    -- Manually initialize configs with YAML format if command fails
    vim.notify("Using fallback initialization method", vim.log.levels.WARN)

    -- Create default YAML configuration
    local default_config = {
      templates = {
        context = "lc-context.j2",
        files = "lc-files.j2",
        highlights = "lc-highlights.j2",
      },
      profiles = {
        code = {
          gitignores = {
            full_files = { ".git", ".gitignore", ".llm-context/", "*.lock" },
            outline_files = { ".git", ".gitignore", ".llm-context/", "*.lock" },
          },
          settings = {
            no_media = true,
            with_user_notes = false,
          },
          ["only-include"] = {
            full_files = { "**/*" },
            outline_files = { "**/*" },
          },
        },
        ["code-prompt"] = {
          base = "code",
          prompt = "lc-prompt.md",
        },
      },
    }

    local yaml_content = utils.YAML.encode(default_config)
    local success = utils.write_file_content(config_dir .. "/" .. CONFIG_FILE, yaml_content)

    if not success then
      vim.notify("Failed to write YAML configuration", vim.log.levels.ERROR)
      return false
    end

    -- Create basic template files
    local template_dir = config_dir .. "/templates"
    if vim.fn.mkdir(template_dir, "p") ~= 1 then
      vim.notify("Failed to create templates directory", vim.log.levels.ERROR)
      return false
    end

    -- Create default templates
    local templates = {
      ["lc-context.j2"] = "{% if prompt %}\n{{ prompt }}\n{% endif %}\n\n# Repository Content: **{{ project_name }}**\n\n## Structure\n{{ folder_structure_diagram }}\n\n{% if files %}\n## Files\n{% include 'lc-files.j2' %}\n{% endif %}",
      ["lc-files.j2"] = "{% for file in files %}\n### {{ file.path }}\n```{{ file.type }}\n{{ file.content }}\n```\n{% endfor %}",
      ["lc-highlights.j2"] = "{% for highlight in highlights %}\n### {{ highlight.path }}\n```{{ highlight.type }}\n{{ highlight.content }}\n```\n{% endfor %}",
    }

    -- Write template files
    for name, content in pairs(templates) do
      if not utils.write_file_content(template_dir .. "/" .. name, content) then
        vim.notify("Failed to write template file: " .. name, vim.log.levels.ERROR)
      end
    end

    -- Create basic prompt
    local prompt_content =
      "## Instructions\n\nYou are helping with a project. Analyze the code provided and assist with development tasks.\n\n## Guidelines\n\n- Explain your reasoning step by step\n- Provide complete, working code solutions\n- Consider best practices and performance\n\n## Response Structure\n\n1. Summary of the codebase\n2. Analysis of the specific task or problem\n3. Solution or implementation\n4. Explanation of your approach"

    if not utils.write_file_content(config_dir .. "/lc-prompt.md", prompt_content) then
      vim.notify("Failed to write prompt file", vim.log.levels.ERROR)
    end

    return true
  end
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

---Update profile with current buffers
---@param profile string? Profile name
---@return boolean success
function LLMContext:update_profile_with_buffers(profile)
  return self.profile_manager:update_profile_with_buffers(profile)
end

---Get current context files
---@return string[] files List of file paths
function LLMContext:get_context_files()
  return self.profile_manager:get_context_files()
end

---Get open buffer files
---@return string[] files List of file paths
function LLMContext:get_open_buffer_files()
  return self.profile_manager:get_open_buffer_files()
end

-- Export the LLMContext class
return LLMContext
