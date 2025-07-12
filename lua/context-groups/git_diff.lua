-- lua/context-groups/git_diff.lua
-- Git diff integration module

local core = require("context-groups.core")

local M = {}

-- Get original content of file from Git
---@param file_path string Path to file
---@return string|nil content Original content from Git
local function get_original_git_content(file_path)
  local handle =
    io.popen(string.format("git show HEAD:%s 2>/dev/null", vim.fn.shellescape(vim.fn.fnamemodify(file_path, ":."))))
  if not handle then
    return nil
  end

  local content = handle:read("*a")
  handle:close()

  -- Check if git command was successful
  if content == "" then
    return nil
  end

  return content
end

-- Get unified diff between current buffer and original file
---@param bufnr number Buffer number
---@param original_content string Original content
---@return string diff Unified diff
local function get_unified_diff(bufnr, original_content)
  -- Get buffer content
  local buffer_content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")

  -- Write contents to temporary files
  local temp_dir = vim.fn.tempname()
  vim.fn.mkdir(temp_dir, "p")

  local original_file = temp_dir .. "/original"
  local buffer_file = temp_dir .. "/buffer"

  vim.fn.writefile(vim.split(original_content, "\n"), original_file)
  vim.fn.writefile(vim.split(buffer_content, "\n"), buffer_file)

  -- Generate diff
  local diff_handle =
    io.popen(string.format("diff -u %s %s", vim.fn.shellescape(original_file), vim.fn.shellescape(buffer_file)))
  local diff_output = diff_handle and diff_handle:read("*a") or "Error generating diff"
  if diff_handle then
    diff_handle:close()
  end

  -- Clean up temporary files
  os.remove(original_file)
  os.remove(buffer_file)
  os.remove(temp_dir)

  -- Process diff output to make it more readable
  -- Remove header lines (first two lines with filenames)
  local lines = vim.split(diff_output, "\n")
  if #lines > 2 then
    table.remove(lines, 1)
    table.remove(lines, 1)
    diff_output = table.concat(lines, "\n")
  end

  return diff_output
end

-- Get buffer with Git diff for a specific buffer
---@param bufnr? number Buffer number (nil for current buffer)
---@return string|nil result Formatted buffer content with Git diff
local function get_buffer_with_git_diff(bufnr)
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

  -- Check if file is tracked by Git
  local original_content = get_original_git_content(buf_name)
  if not original_content then
    return string.format("## %s\n\nFile not tracked in Git", path)
  end

  -- Get current buffer content
  local buffer_content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")

  -- If no changes, return early
  if original_content == buffer_content then
    return string.format("## %s\n\nNo changes", path)
  end

  -- Get diff
  local diff = get_unified_diff(bufnr, original_content)

  -- Construct output
  local result = {
    string.format("## %s\n", path),
    "### Original (Git)\n```",
    original_content,
    "```\n",
    "### Current\n```",
    buffer_content,
    "```\n",
    "### Diff\n```diff",
    diff,
    "```",
  }

  return table.concat(result, "\n")
end

-- Get current buffer with Git diff and copy to clipboard
---@return boolean success
function M.get_current_buffer_with_git_diff()
  local bufnr = vim.api.nvim_get_current_buf()
  local content = get_buffer_with_git_diff(bufnr)

  if not content then
    vim.notify("Cannot generate Git diff for current buffer", vim.log.levels.WARN)
    return false
  end

  -- Copy to clipboard
  vim.fn.setreg("+", content)
  vim.notify("Current buffer with Git diff copied to clipboard", vim.log.levels.INFO)
  return true
end

-- Get all modified buffers with Git diff and copy to clipboard
---@return boolean success
function M.get_all_modified_buffers_with_git_diff()
  local buffer_paths, project_root = core.get_open_buffer_paths()

  if #buffer_paths == 0 then
    vim.notify("No open buffer files found", vim.log.levels.ERROR)
    return false
  end

  -- Build combined output
  local results = {
    string.format("# Git diffs for project %s\n", vim.fn.fnamemodify(project_root, ":t")),
  }

  local modified_count = 0

  for _, _ in ipairs(vim.api.nvim_list_bufs()) do
    local bufnr = _
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
      local content = get_buffer_with_git_diff(bufnr)
      if content and not content:match("No changes") and not content:match("File not tracked in Git") then
        table.insert(results, content)
        table.insert(results, "\n---\n")
        modified_count = modified_count + 1
      end
    end
  end

  if modified_count == 0 then
    vim.notify("No modified buffers found", vim.log.levels.WARN)
    return false
  end

  local final_output = table.concat(results, "\n")

  -- Copy to clipboard
  vim.fn.setreg("+", final_output)
  vim.notify(
    string.format("Git diffs for %d modified buffers copied to clipboard", modified_count),
    vim.log.levels.INFO
  )
  return true
end

return M