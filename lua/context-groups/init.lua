-- lua/context-groups/init.lua

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
  require("context-groups.ui.picker").show_context_group()
end

-- Show imports picker
function M.show_imports_picker()
  require("context-groups.ui.picker").show_imports_picker()
end

-- Export codebase contents
---@param opts table Export options
---@return table? Export result
function M.export_contents(opts)
  return require("context-groups.core.export").export_contents(opts)
end

return M
