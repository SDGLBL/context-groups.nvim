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

-- Call code2prompt on all open buffers
---@return boolean success
function M.call_code2prompt()
  -- Get LLM context to access open buffer files
  local llm_ctx = M.get_llm_context()

  -- Call code2prompt module to generate prompt
  return require("context-groups.code2prompt").generate_prompt(llm_ctx)
end

-- Get LSP diagnostics for current buffer
---@return boolean success
function M.get_lsp_diagnostics_current()
  return require("context-groups.lsp_diagnostics").get_current_buffer_diagnostics()
end

-- Get LSP diagnostics for all open buffers
---@return boolean success
function M.get_lsp_diagnostics_all()
  return require("context-groups.lsp_diagnostics").get_all_buffer_diagnostics()
end

-- Get current buffer with inline LSP diagnostics
---@return boolean success
function M.get_inline_lsp_diagnostics_current()
  return require("context-groups.lsp_diagnostics_inline").get_current_buffer_with_inline_diagnostics()
end

-- Get all buffers with inline LSP diagnostics
---@return boolean success
function M.get_inline_lsp_diagnostics_all()
  return require("context-groups.lsp_diagnostics_inline").get_all_buffers_with_inline_diagnostics()
end

-- Get current buffer with Git diff
---@return boolean success
function M.get_git_diff_current()
  return require("context-groups.git_diff_inline").get_current_buffer_with_git_diff()
end

-- Get all modified buffers with Git diff
---@return boolean success
function M.get_git_diff_all_modified()
  return require("context-groups.git_diff_inline").get_all_modified_buffers_with_git_diff()
end

-- Copy the relative paths of all open buffers to clipboard
---@return boolean success
function M.get_buffer_paths()
  local llm_ctx = M.get_llm_context()
  local root = llm_ctx.root
  local buffer_paths = {}

  -- Get all open buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
      local path = vim.api.nvim_buf_get_name(bufnr)

      -- Skip empty buffers
      if path and path ~= "" and vim.fn.filereadable(path) == 1 then
        path = vim.fn.fnamemodify(path, ":p")
        if vim.startswith(path, root) then
          -- Convert to relative path
          path = path:sub(#root + 2) -- +2 to remove the trailing slash
          table.insert(buffer_paths, path)
        end
      end
    end
  end

  if #buffer_paths == 0 then
    vim.notify("No valid open buffer files found", vim.log.levels.ERROR)
    return false
  end

  -- Sort paths for consistency
  table.sort(buffer_paths)

  -- Copy to clipboard
  local text = table.concat(buffer_paths, "\n")
  vim.fn.setreg("+", text)

  vim.notify(string.format("Paths of %d open buffers copied to clipboard", #buffer_paths), vim.log.levels.INFO)
  return true
end

return M
