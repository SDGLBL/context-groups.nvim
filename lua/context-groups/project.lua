-- lua/context-groups/project.lua
-- Project utilities extracted from core.lua

local config = require("context-groups.config")
local utils = require("context-groups.utils")

local M = {}

-- Cache for project roots
---@type table<string, string>
local root_cache = {}

---Find project root for given path
---@param path string File path
---@return string root Project root path
function M.find_root(path)
  -- Check cache first
  if root_cache[path] then
    return root_cache[path]
  end

  local current_dir = vim.fn.fnamemodify(path, ":h")
  local markers = config.get().project_markers

  -- Look for project markers
  local function has_marker(dir)
    for _, marker in ipairs(markers) do
      local marker_path = dir .. "/" .. marker
      if vim.fn.filereadable(marker_path) == 1 or vim.fn.isdirectory(marker_path) == 1 then
        return true
      end
    end
    return false
  end

  -- Walk up directory tree
  while current_dir ~= "/" do
    if has_marker(current_dir) then
      root_cache[path] = current_dir
      return current_dir
    end
    current_dir = vim.fn.fnamemodify(current_dir, ":h")
  end

  -- Fallback to current working directory
  local fallback = vim.fn.getcwd()
  root_cache[path] = fallback
  return fallback
end

---Clear project root cache
function M.clear_cache()
  root_cache = {}
end

---Get relative path from project root
---@param path string Absolute file path
---@return string relative_path Path relative to project root
function M.get_relative_path(path)
  local root = M.find_root(path)
  return utils.get_relative_path(path, root)
end

---Check if path is in current project
---@param path string File path to check
---@return boolean is_in_project
function M.is_in_project(path)
  local root = M.find_root(vim.fn.expand("%:p"))
  return vim.startswith(path, root)
end

---Get all project files
---@param root? string Project root (default: current file's project)
---@return string[] files List of project files
function M.get_files(root)
  root = root or M.find_root(vim.fn.expand("%:p"))

  -- Use ripgrep if available
  if vim.fn.executable("rg") == 1 then
    local cmd = string.format("rg --files %s", vim.fn.shellescape(root))
    local handle = io.popen(cmd)
    if handle then
      local result = handle:read("*a")
      handle:close()
      return vim.split(result, "\n")
    end
  end

  -- Fallback to find
  local cmd = string.format("find %s -type f", vim.fn.shellescape(root))
  local handle = io.popen(cmd)
  if handle then
    local result = handle:read("*a")
    handle:close()
    return vim.split(result, "\n")
  end

  return {}
end

---Get paths of all open buffers
---@return string[] paths List of relative file paths from project root
---@return string root Project root directory
function M.get_open_buffer_paths()
  local root = M.find_root(vim.fn.expand("%:p"))
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

  -- Sort paths for consistency
  table.sort(buffer_paths)

  return buffer_paths, root
end

return M
