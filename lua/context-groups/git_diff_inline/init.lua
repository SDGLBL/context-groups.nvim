-- lua/context-groups/git_diff_inline/init.lua
-- Module for getting git diff with inline annotations

local M = {}

-- Get original content from Git
---@param file_path string Absolute file path
---@return string|nil content Original file content from Git
local function get_git_original_content(file_path)
  -- Get the repo root directory
  local handle = io.popen(
    string.format("cd %s && git rev-parse --show-toplevel", vim.fn.shellescape(vim.fn.fnamemodify(file_path, ":h")))
  )

  if not handle then
    return nil
  end

  local repo_root = handle:read("*l")
  handle:close()

  if not repo_root or repo_root == "" then
    return nil -- Not a git repository
  end

  -- Get relative path from repo root
  local rel_path = file_path
  if vim.startswith(file_path, repo_root) then
    rel_path = file_path:sub(#repo_root + 2) -- +2 to remove the trailing slash
  end

  -- Check if file is tracked by git
  handle = io.popen(
    string.format(
      "cd %s && git ls-files --error-unmatch %s 2>/dev/null || echo 'not-tracked'",
      vim.fn.shellescape(repo_root),
      vim.fn.shellescape(rel_path)
    )
  )

  if not handle then
    return nil
  end

  local tracked = handle:read("*l")
  handle:close()

  if tracked == "not-tracked" then
    return nil -- File is not tracked by git
  end

  -- Get the original content from Git HEAD
  handle = io.popen(
    string.format(
      "cd %s && git show HEAD:%s 2>/dev/null || echo 'not-in-git'",
      vim.fn.shellescape(repo_root),
      vim.fn.shellescape(rel_path)
    )
  )

  if not handle then
    return nil
  end

  local content = handle:read("*a")
  handle:close()

  if content == "not-in-git" then
    return nil -- File is not in git yet
  end

  return content
end

-- Format a single buffer with git diff annotations
---@param bufnr number Buffer number
---@return string|nil formatted_content
local function format_buffer_with_git_diff(bufnr)
  local buf_name = vim.api.nvim_buf_get_name(bufnr)

  -- Skip unnamed buffers
  if buf_name == "" then
    return nil
  end

  -- Get relative path if possible
  local llm_ctx = require("context-groups").get_llm_context()
  local path = buf_name
  if vim.startswith(buf_name, llm_ctx.root) then
    path = buf_name:sub(#llm_ctx.root + 2) -- +2 to remove the trailing slash
  end

  -- Get current buffer content
  local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local current_content = table.concat(current_lines, "\n")

  -- Get original content from Git
  local original_content = get_git_original_content(buf_name)

  if not original_content then
    return string.format("File: %s\n\nThis file is not tracked by Git or has no previous version.", path)
  end

  -- Split original content into lines
  local original_lines = vim.split(original_content, "\n")

  -- Format the output
  local formatted_lines = {}
  table.insert(formatted_lines, string.format("File: %s", path))

  -- Add Git version
  table.insert(formatted_lines, "\n## Git Original Version")
  table.insert(formatted_lines, "```" .. (vim.bo[bufnr].filetype or ""))
  for _, line in ipairs(original_lines) do
    table.insert(formatted_lines, line)
  end
  table.insert(formatted_lines, "```")

  -- Add Current version
  table.insert(formatted_lines, "\n## Current Buffer Version")
  table.insert(formatted_lines, "```" .. (vim.bo[bufnr].filetype or ""))
  for _, line in ipairs(current_lines) do
    table.insert(formatted_lines, line)
  end
  table.insert(formatted_lines, "```")

  -- Add Git diff command output for reference
  handle = io.popen(
    string.format(
      "cd %s && git diff --color=never -- %s",
      vim.fn.shellescape(vim.fn.fnamemodify(buf_name, ":h")),
      vim.fn.shellescape(buf_name)
    )
  )

  if handle then
    local diff_output = handle:read("*a")
    handle:close()

    if diff_output and diff_output ~= "" then
      table.insert(formatted_lines, "\n## Git Diff Output")
      table.insert(formatted_lines, "```diff")
      table.insert(formatted_lines, diff_output)
      table.insert(formatted_lines, "```")
    end
  end

  return table.concat(formatted_lines, "\n")
end

-- Get current buffer with git diff
---@return boolean success
function M.get_current_buffer_with_git_diff()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    vim.notify("Invalid buffer", vim.log.levels.ERROR)
    return false
  end

  local formatted = format_buffer_with_git_diff(bufnr)

  if not formatted then
    vim.notify("Could not get Git diff for current buffer", vim.log.levels.ERROR)
    return false
  end

  -- Add format instructions at the beginning
  local instructions = [[# Git Diff and Current Buffer Format Guide

This output shows:
1. The original version of the file from Git
2. The current version in your buffer
3. Git diff output showing what changed

The content is organized into sections:
- "Git Original Version" - The content from the most recent Git commit
- "Current Buffer Version" - The current state of your buffer
- "Git Diff Output" - Standard Git diff format showing the changes

---

]]

  -- Copy to clipboard with instructions
  vim.fn.setreg("+", instructions .. formatted)

  vim.notify("Current buffer with Git diff copied to clipboard", vim.log.levels.INFO)
  return true
end

-- Get all modified buffers with git diff
---@return boolean success
function M.get_all_modified_buffers_with_git_diff()
  local llm_ctx = require("context-groups").get_llm_context()
  local all_formatted = {}
  local count = 0

  -- Process all open buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
      local path = vim.api.nvim_buf_get_name(bufnr)

      -- Skip empty buffers
      if path and path ~= "" and vim.fn.filereadable(path) == 1 then
        -- Check if buffer is modified compared to git
        local is_modified = false
        local handle = io.popen(
          string.format(
            "cd %s && git diff --quiet -- %s || echo 'modified'",
            vim.fn.shellescape(vim.fn.fnamemodify(path, ":h")),
            vim.fn.shellescape(path)
          )
        )

        if handle then
          local result = handle:read("*a")
          handle:close()
          is_modified = (result:match("modified") ~= nil)
        end

        if is_modified then
          count = count + 1
          local buffer_formatted = format_buffer_with_git_diff(bufnr)
          if buffer_formatted then
            table.insert(all_formatted, buffer_formatted)
          end
        end
      end
    end
  end

  if count == 0 then
    vim.notify("No modified buffers found compared to Git", vim.log.levels.INFO)
    return false
  end

  -- Add format instructions at the beginning
  local instructions = [[# Git Diff and Current Buffers Format Guide

This output shows for each modified file:
1. The original version of the file from Git
2. The current version in your buffer
3. Git diff output showing what changed

The content is organized into sections for each file:
- "Git Original Version" - The content from the most recent Git commit
- "Current Buffer Version" - The current state of your buffer
- "Git Diff Output" - Standard Git diff format showing the changes
- Multiple files are separated by `---`

---

]]

  -- Add header and combine all formatted content
  local header = "# Modified Buffers with Git Diff\n\n"
  local text = instructions .. header .. table.concat(all_formatted, "\n\n---\n\n")

  -- Copy to clipboard
  vim.fn.setreg("+", text)

  vim.notify(string.format("Git diff from %d modified buffers copied to clipboard", count), vim.log.levels.INFO)
  return true
end

return M

