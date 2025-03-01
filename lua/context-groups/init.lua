-- lua/context-groups/init.lua
-- Main entry point for context-groups plugin

local config = require("context-groups.config")
local core = require("context-groups.core")
local lsp = require("context-groups.lsp")
local ui = require("context-groups.ui")

---@class ContextGroups
local M = {}

-- Setup the plugin
---@param opts ContextGroupsConfig Configuration options
function M.setup(opts)
  -- Initialize configuration
  config.setup(opts or {})

  -- Setup LSP integration
  lsp.setup()

  -- Setup UI components
  ui.setup()
end

-- Add file to context group
---@param file string File path
---@param bufnr? number Target buffer number
---@return boolean success
function M.add_context_file(file, bufnr)
  return core.add_context_file(file, bufnr)
end

-- Remove file from context group
---@param file string File path
---@param bufnr? number Target buffer number
---@return boolean success
function M.remove_context_file(file, bufnr)
  return core.remove_context_file(file, bufnr)
end

-- Get context files
---@param bufnr? number Target buffer number
---@return string[] files List of file paths
function M.get_context_files(bufnr)
  return core.get_context_files(bufnr)
end

-- Get context contents
---@param bufnr? number Target buffer number
---@return table[] contents List of file contents with metadata
function M.get_context_contents(bufnr)
  return core.get_context_contents(bufnr)
end

-- Clear context group
---@param bufnr? number Target buffer number
---@return boolean success
function M.clear_context_group(bufnr)
  return core.clear_context_group(bufnr)
end

-- Show context group picker
function M.show_context_group()
  require("context-groups.picker").show_context_group()
end

-- Show profile picker
function M.show_profile_picker()
  require("context-groups.picker").show_profile_picker()
end

-- Show imports picker
function M.show_imports_picker()
  require("context-groups.picker").show_imports_picker()
end

-- Export codebase contents
---@param opts table Export options
---@return table? Export result
function M.export_contents(opts)
  return core.export.export_contents(opts)
end

-- LLM Context Integration API

-- Get LLM Context for current project
---@return LLMContext
function M.get_llm_context()
  local root = core.find_root(vim.fn.expand("%:p"))
  return require("context-groups.llm").new(root)
end

-- Initialize LLM Context for current project
---@return boolean success
function M.init_llm_context()
  local llm_ctx = M.get_llm_context()
  return llm_ctx:is_initialized() or llm_ctx:initialize()
end

-- Get available LLM Context profiles
---@return string[] profile_names
function M.get_llm_profiles()
  local llm_ctx = M.get_llm_context()
  return llm_ctx:get_profiles()
end

-- Switch to LLM Context profile
---@param profile string Profile name
---@return boolean success
function M.switch_llm_profile(profile)
  local llm_ctx = M.get_llm_context()
  return llm_ctx:switch_profile(profile)
end

-- Create LLM Context profile from current context
---@param name string Profile name
---@return boolean success
function M.create_llm_profile(name)
  local llm_ctx = M.get_llm_context()
  local context_files = llm_ctx:get_open_buffer_files()
  return llm_ctx:create_profile_from_context(name, context_files)
end

-- Sync context group with LLM Context
---@return boolean success
function M.sync_llm_context()
  local llm_ctx = M.get_llm_context()
  local current_profile = llm_ctx:get_current_profile()

  if not current_profile then
    vim.notify("No active profile", vim.log.levels.WARN)
    return false
  end

  local success = llm_ctx:update_profile_with_buffers(current_profile)
  if success then
    llm_ctx:update_files()
    return true
  end

  return false
end

return M
