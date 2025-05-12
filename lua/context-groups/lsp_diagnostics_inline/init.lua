-- lua/context-groups/lsp_diagnostics_inline/init.lua
-- Inline LSP diagnostics module

local core = require("context-groups.core")

local M = {}

-- Get buffer content with inline LSP diagnostics
---@param bufnr? number Buffer number
---@return string|nil result Formatted buffer content with diagnostics
local function get_buffer_with_inline_diagnostics(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  -- Get buffer name and check if valid
  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  if buf_name == "" then
    return nil
  end
  
  -- Convert to relative path
  local path = buf_name
  local project_root = core.find_root(buf_name)
  if vim.startswith(buf_name, project_root) then
    path = buf_name:sub(#project_root + 2) -- +2 to remove the trailing slash
  end

  -- Get all lines from buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if not lines or #lines == 0 then
    return string.format("## %s\n(Empty file)", path)
  end

  -- Get diagnostics for buffer
  local diags = vim.diagnostic.get(bufnr)
  local diags_by_line = {}
  
  for _, diag in ipairs(diags) do
    local line = diag.lnum
    diags_by_line[line] = diags_by_line[line] or {}
    table.insert(diags_by_line[line], diag)
  end
  
  -- Sort diagnostics on each line by severity then column
  for line, line_diags in pairs(diags_by_line) do
    table.sort(line_diags, function(a, b)
      if a.severity == b.severity then
        return a.col < b.col
      end
      return a.severity < b.severity
    end)
  end

  -- Construct output
  local result = { string.format("## %s\n```", path) }
  
  for i, line in ipairs(lines) do
    local line_num = i - 1 -- Convert to 0-based line number
    
    -- Add the code line with line number
    table.insert(result, string.format("%4d: %s", i, line))
    
    -- Add inline diagnostics if any
    if diags_by_line[line_num] then
      for _, diag in ipairs(diags_by_line[line_num]) do
        local severity = {"ERROR", "WARN", "INFO", "HINT"}[diag.severity]
        local col = diag.col + 1 -- Convert to 1-based column
        local message = diag.message:gsub("\n", " ")
        
        -- Create position indicator with caret (^)
        local indent = string.rep(" ", 6 + col - 1) -- 6 = "dddd: " prefix length
        table.insert(result, string.format("%s^ %s: %s", indent, severity, message))
      end
    end
  end
  
  table.insert(result, "```")
  return table.concat(result, "\n")
end

-- Get current buffer with inline LSP diagnostics and copy to clipboard
---@return boolean success
function M.get_current_buffer_with_inline_diagnostics()
  local bufnr = vim.api.nvim_get_current_buf()
  local content = get_buffer_with_inline_diagnostics(bufnr)
  
  if not content then
    vim.notify("No valid content for current buffer", vim.log.levels.WARN)
    return false
  end
  
  -- Copy to clipboard
  vim.fn.setreg("+", content)
  vim.notify("Current buffer with inline LSP diagnostics copied to clipboard", vim.log.levels.INFO)
  return true
end

-- Get all open buffers with inline LSP diagnostics and copy to clipboard
---@return boolean success
function M.get_all_buffers_with_inline_diagnostics()
  local buffer_paths, project_root = core.get_open_buffer_paths()
  
  if #buffer_paths == 0 then
    vim.notify("No open buffer files found", vim.log.levels.ERROR)
    return false
  end
  
  -- Build combined diagnostics
  local results = {
    string.format("# LSP Diagnostics for project %s\n", vim.fn.fnamemodify(project_root, ":t")),
  }
  
  local count = 0
  for _, _ in ipairs(buffer_paths) do
    count = count + 1
  end
  
  for _, _ in ipairs(vim.api.nvim_list_bufs()) do
    local bufnr = _
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
      local content = get_buffer_with_inline_diagnostics(bufnr)
      if content then
        table.insert(results, content)
        table.insert(results, "\n---\n")
      end
    end
  end
  
  local final_output = table.concat(results, "\n")
  
  -- Copy to clipboard
  vim.fn.setreg("+", final_output)
  vim.notify(string.format("LSP diagnostics for %d buffers copied to clipboard", count), vim.log.levels.INFO)
  return true
end

return M
