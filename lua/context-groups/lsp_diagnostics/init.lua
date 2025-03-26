-- lua/context-groups/lsp_diagnostics/init.lua
-- Module for getting LSP diagnostics information

local M = {}

-- Severity mapping
local severity_labels = {
  [1] = "ERROR",
  [2] = "WARNING",
  [3] = "INFORMATION",
  [4] = "HINT",
}

-- Format diagnostics for a buffer
---@param bufnr number Buffer number
---@param filetype string File type
---@return string[] formatted_diagnostics
local function format_buffer_diagnostics(bufnr, filetype)
  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  -- Get relative path if possible
  local llm_ctx = require("context-groups").get_llm_context()
  local path = buf_name
  if vim.startswith(buf_name, llm_ctx.root) then
    path = buf_name:sub(#llm_ctx.root + 2) -- +2 to remove the trailing slash
  end

  local diagnostics = vim.diagnostic.get(bufnr, {
    severity = { min = vim.diagnostic.severity.HINT },
  })

  if #diagnostics == 0 then
    return { string.format("File: %s\nNo LSP diagnostics found.", path) }
  end

  local formatted = {}
  table.insert(formatted, string.format("File: %s", path))

  -- Add code to the diagnostics
  for _, diagnostic in ipairs(diagnostics) do
    -- Get the code at the diagnostic position
    local lines = {}
    for i = diagnostic.lnum, diagnostic.end_lnum do
      local line_content = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1] or ""
      table.insert(lines, string.format("%d: %s", i + 1, vim.trim(line_content)))
    end

    -- Format the diagnostic
    table.insert(
      formatted,
      string.format(
        [[
Severity: %s
Position: Line %d, Column %d
LSP Message: %s
Code:
```%s
%s
```]],
        severity_labels[diagnostic.severity] or "UNKNOWN",
        diagnostic.lnum + 1, -- Convert to 1-based line number
        diagnostic.col + 1, -- Convert to 1-based column
        diagnostic.message,
        filetype,
        table.concat(lines, "\n")
      )
    )
  end

  return formatted
end

-- Generate diagnostic information for the current buffer
---@return boolean success
function M.get_current_buffer_diagnostics()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    vim.notify("Invalid buffer", vim.log.levels.ERROR)
    return false
  end

  local filetype = vim.bo[bufnr].filetype
  local formatted = format_buffer_diagnostics(bufnr, filetype)

  -- Copy to clipboard
  local text = table.concat(formatted, "\n\n")
  vim.fn.setreg("+", text)

  vim.notify("LSP diagnostics from current buffer copied to clipboard", vim.log.levels.INFO)
  return true
end

-- Generate diagnostic information for all open buffers
---@return boolean success
function M.get_all_buffer_diagnostics()
  local llm_ctx = require("context-groups").get_llm_context()
  local all_formatted = {}
  local count = 0

  -- Process all open buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
      local path = vim.api.nvim_buf_get_name(bufnr)

      -- Skip empty buffers
      if path and path ~= "" and vim.fn.filereadable(path) == 1 then
        local filetype = vim.bo[bufnr].filetype
        local buffer_diagnostics = format_buffer_diagnostics(bufnr, filetype)

        if #buffer_diagnostics > 0 then
          count = count + 1
          table.insert(all_formatted, table.concat(buffer_diagnostics, "\n\n"))
        end
      end
    end
  end

  if count == 0 then
    vim.notify("No LSP diagnostics found in any open buffer", vim.log.levels.INFO)
    return false
  end

  -- Add header
  local header = "# LSP Diagnostics from Open Buffers\n\n"
  local text = header .. table.concat(all_formatted, "\n\n---\n\n")

  -- Copy to clipboard
  vim.fn.setreg("+", text)

  vim.notify(string.format("LSP diagnostics from %d buffers copied to clipboard", count), vim.log.levels.INFO)
  return true
end

return M
