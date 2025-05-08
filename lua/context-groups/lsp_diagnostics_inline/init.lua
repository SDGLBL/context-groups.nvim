-- lua/context-groups/lsp_diagnostics_inline/init.lua
-- Module for getting LSP diagnostics information with inline annotations

local M = {}

-- Severity mapping
local severity_labels = {
  [1] = "ERROR",
  [2] = "WARNING",
  [3] = "INFORMATION",
  [4] = "HINT",
}

-- Format a single buffer content with inline diagnostics
---@param bufnr number Buffer number
---@return string formatted_content
local function format_buffer_with_inline_diagnostics(bufnr)
  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  -- Get relative path if possible
  local llm_ctx = require("context-groups").get_llm_context()
  local path = buf_name
  if vim.startswith(buf_name, llm_ctx.root) then
    path = buf_name:sub(#llm_ctx.root + 2) -- +2 to remove the trailing slash
  end

  -- Get buffer content
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  
  -- Get diagnostics for the buffer
  local diagnostics = vim.diagnostic.get(bufnr)
  
  -- Group diagnostics by line
  local diags_by_line = {}
  for _, diag in ipairs(diagnostics) do
    diags_by_line[diag.lnum] = diags_by_line[diag.lnum] or {}
    table.insert(diags_by_line[diag.lnum], diag)
  end
  
  -- Format each line with its diagnostics
  local formatted_lines = {}
  table.insert(formatted_lines, string.format("File: %s", path))
  table.insert(formatted_lines, "```" .. (vim.bo[bufnr].filetype or ""))
  
  for i, line in ipairs(lines) do
    local line_index = i - 1 -- Convert to 0-based index for diagnostics
    local line_diags = diags_by_line[line_index]
    
    if line_diags and #line_diags > 0 then
      -- Format diagnostics for this line
      local diag_messages = {}
      for _, diag in ipairs(line_diags) do
        table.insert(diag_messages, string.format("[%s]: %s", 
          severity_labels[diag.severity] or "UNKNOWN", 
          diag.message))
      end
      
      -- Append diagnostics to the line
      table.insert(formatted_lines, line .. " <-- " .. table.concat(diag_messages, " , "))
    else
      -- Line without diagnostics
      table.insert(formatted_lines, line)
    end
  end
  
  table.insert(formatted_lines, "```")
  return table.concat(formatted_lines, "\n")
end

-- Generate diagnostic information for the current buffer with inline annotations
---@return boolean success
function M.get_current_buffer_with_inline_diagnostics()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    vim.notify("Invalid buffer", vim.log.levels.ERROR)
    return false
  end

  local formatted = format_buffer_with_inline_diagnostics(bufnr)

  -- Add format instructions at the beginning
  local instructions = [[# Inline LSP Diagnostics Format Guide

- Each line with diagnostics is formatted as: `code <-- [SEVERITY]: message`
- Severity levels:
  - [ERROR]: Critical issues that need to be fixed
  - [WARNING]: Potential problems or code smells
  - [INFORMATION]: Informational hints from LSP
  - [HINT]: Suggestions for improvement
- Lines without diagnostics are shown as-is

---

]]

  -- Copy to clipboard with instructions
  vim.fn.setreg("+", instructions .. formatted)

  vim.notify("Current buffer with inline diagnostics copied to clipboard", vim.log.levels.INFO)
  return true
end

-- Generate diagnostic information for all open buffers with inline annotations
---@return boolean success
function M.get_all_buffers_with_inline_diagnostics()
  local llm_ctx = require("context-groups").get_llm_context()
  local all_formatted = {}
  local count = 0

  -- Process all open buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
      local path = vim.api.nvim_buf_get_name(bufnr)

      -- Skip empty buffers
      if path and path ~= "" and vim.fn.filereadable(path) == 1 then
        count = count + 1
        local buffer_formatted = format_buffer_with_inline_diagnostics(bufnr)
        table.insert(all_formatted, buffer_formatted)
      end
    end
  end

  if count == 0 then
    vim.notify("No valid open buffer files found", vim.log.levels.INFO)
    return false
  end

  -- Add format instructions at the beginning
  local instructions = [[# Inline LSP Diagnostics Format Guide

- Each line with diagnostics is formatted as: `code <-- [SEVERITY]: message`
- Severity levels:
  - [ERROR]: Critical issues that need to be fixed
  - [WARNING]: Potential problems or code smells
  - [INFORMATION]: Informational hints from LSP
  - [HINT]: Suggestions for improvement
- Lines without diagnostics are shown as-is
- Multiple files are separated by `---`

---

]]

  -- Add header and combine all formatted content
  local header = "# Files with Inline LSP Diagnostics\n\n"
  local text = instructions .. header .. table.concat(all_formatted, "\n\n---\n\n")

  -- Copy to clipboard
  vim.fn.setreg("+", text)

  vim.notify(string.format("Inline diagnostics from %d buffers copied to clipboard", count), vim.log.levels.INFO)
  return true
end

return M