-- lua/context-groups/init.lua
-- Main entry point for context-groups plugin

local config = require("context-groups.config")
local core = require("context-groups.core")
local ui = require("context-groups.ui")

---@class ContextGroups
local M = {}

-- Setup the plugin
---@param opts ContextGroupsConfig Configuration options
function M.setup(opts)
  -- Initialize configuration
  config.setup(opts or {})

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

-- Call code2prompt on current buffer
---@return boolean success
function M.call_code2prompt_current()
  -- Call code2prompt module to generate prompt for current buffer
  return require("context-groups.code2prompt").generate_current_buffer_prompt()
end

-- Call code2prompt on all open buffers
---@return boolean success
function M.call_code2prompt()
  -- Call code2prompt module to generate prompt
  return require("context-groups.code2prompt").generate_prompt()
end

-- Get LSP diagnostics for current buffer
---@return boolean success
function M.get_lsp_diagnostics_current()
  return require("context-groups.diagnostics").get_current_buffer_diagnostics()
end

-- Get LSP diagnostics for all open buffers
---@return boolean success
function M.get_lsp_diagnostics_all()
  return require("context-groups.diagnostics").get_all_buffer_diagnostics()
end

-- Get current buffer with inline LSP diagnostics
---@return boolean success
function M.get_inline_lsp_diagnostics_current()
  return require("context-groups.diagnostics").get_current_buffer_with_inline_diagnostics()
end

-- Get all buffers with inline LSP diagnostics
---@return boolean success
function M.get_inline_lsp_diagnostics_all()
  return require("context-groups.diagnostics").get_all_buffers_with_inline_diagnostics()
end

-- Get current buffer with Git diff
---@return boolean success
function M.get_git_diff_current()
  return require("context-groups.git_diff").get_current_buffer_with_git_diff()
end

-- Get all modified buffers with Git diff
---@return boolean success
function M.get_git_diff_all_modified()
  return require("context-groups.git_diff").get_all_modified_buffers_with_git_diff()
end

-- Copy the relative paths of all open buffers to clipboard
---@return boolean success
function M.get_buffer_paths()
  local buffer_paths, root = core.get_open_buffer_paths()

  if #buffer_paths == 0 then
    vim.notify("No valid open buffer files found", vim.log.levels.ERROR)
    return false
  end

  -- Copy to clipboard
  local text = table.concat(buffer_paths, "\n")
  vim.fn.setreg("+", text)

  vim.notify(string.format("Paths of %d open buffers copied to clipboard", #buffer_paths), vim.log.levels.INFO)
  return true
end

return M
