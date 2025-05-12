-- lua/context-groups/lsp_diagnostics/init.lua
-- LSP diagnostics module

local core = require("context-groups.core")

local M = {}

-- Get LSP diagnostics for current buffer
---@param bufnr? number Buffer number
---@return string|nil diagnostics Formatted diagnostics
local function get_buffer_diagnostics(bufnr)
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

  -- Get diagnostics for buffer
  local diags = vim.diagnostic.get(bufnr)
  if not diags or #diags == 0 then
    return string.format("## %s\nNo diagnostics found", path)
  end

  -- Sort diagnostics by severity
  table.sort(diags, function(a, b)
    if a.severity == b.severity then
      if a.lnum == b.lnum then
        return a.col < b.col
      end
      return a.lnum < b.lnum
    end
    return a.severity < b.severity
  end)

  -- Construct output
  local result = { string.format("## %s\n", path) }
  
  for _, diag in ipairs(diags) do
    local severity = {"Error", "Warning", "Info", "Hint"}[diag.severity]
    local line = diag.lnum + 1 -- Convert to 1-based line number
    local col = diag.col + 1 -- Convert to 1-based column number
    local message = diag.message:gsub("\n", " ")
    
    -- Get a snippet of code around the diagnostic
    local context_start = math.max(0, diag.lnum - 1)
    local context_end = math.min(vim.api.nvim_buf_line_count(bufnr) - 1, diag.lnum + 1)
    local context_lines = vim.api.nvim_buf_get_lines(bufnr, context_start, context_end + 1, false)
    
    -- Add diagnostic location and message
    table.insert(result, string.format("**%s** at line %d, column %d: %s", severity, line, col, message))
    
    -- Add code context with line numbers
    if #context_lines > 0 then
      table.insert(result, "```")
      for i, cline in ipairs(context_lines) do
        local lnum = context_start + i
        local prefix = lnum == diag.lnum and ">" or " "
        table.insert(result, string.format("%s %3d: %s", prefix, lnum + 1, cline))
      end
      table.insert(result, "```\n")
    end
  end
  
  return table.concat(result, "\n")
end

-- Get diagnostics for current buffer and copy to clipboard
---@return boolean success
function M.get_current_buffer_diagnostics()
  local bufnr = vim.api.nvim_get_current_buf()
  local diagnostics = get_buffer_diagnostics(bufnr)
  
  if not diagnostics then
    vim.notify("No diagnostics available for current buffer", vim.log.levels.WARN)
    return false
  end
  
  -- Copy to clipboard
  vim.fn.setreg("+", diagnostics)
  vim.notify("LSP diagnostics for current buffer copied to clipboard", vim.log.levels.INFO)
  return true
end

-- Get diagnostics for all open buffers and copy to clipboard
---@return boolean success
function M.get_all_buffer_diagnostics()
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
      local diags = get_buffer_diagnostics(bufnr)
      if diags then
        table.insert(results, diags)
        table.insert(results, "---\n")
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
