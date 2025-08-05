-- lua/context-groups/core.lua
-- Core context management functionality

local config = require("context-groups.config")
local project = require("context-groups.project")
local storage = require("context-groups.storage")
local utils = require("context-groups.utils")

local M = {}

-- Re-export functions from project module for backward compatibility
M.find_root = project.find_root
M.clear_cache = project.clear_cache
M.get_relative_path = project.get_relative_path
M.is_in_project = project.is_in_project
M.get_files = project.get_files
M.get_open_buffer_paths = project.get_open_buffer_paths

-- Re-export export functionality for backward compatibility
M.export = require("context-groups.export")

---Get current file path
---@param bufnr number|nil Buffer number
---@return string|nil filepath File path or nil
local function get_current_filepath(bufnr)
  -- If buffer number provided, try to get path from it
  if bufnr then
    local path = vim.api.nvim_buf_get_name(bufnr)
    if path and path ~= "" and vim.fn.filereadable(path) == 1 then
      return path
    end
  end

  -- Try to get file path from current window
  local current_buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(current_buf)
  if path and path ~= "" and vim.fn.filereadable(path) == 1 then
    return path
  end

  -- If still failing, try to get current working directory
  local cwd = vim.fn.getcwd()
  if cwd and cwd ~= "" then
    return cwd
  end

  return nil
end

---Get context files for a buffer
---@param bufnr integer|nil Buffer number (nil for current buffer)
---@param opts? {relative: boolean} Options {relative: Return relative paths (default false)}
---@return string[] context_files List of context files
function M.get_context_files(bufnr, opts)
  local file_path = get_current_filepath(bufnr)
  if not file_path then
    vim.notify("No valid file path found", vim.log.levels.WARN)
    return {}
  end

  local root = M.find_root(file_path)
  local store = storage.get_storage(root)

  -- Get context group for current file
  local context_group = store:get(file_path) or {}

  -- Filter out non-existent files and convert to relative paths if needed
  return vim.tbl_map(
    function(file)
      -- Only process existing files
      if vim.fn.filereadable(file) == 1 and opts and opts.relative then
        return M.get_relative_path(file)
      end
      return file
    end,
    vim.tbl_filter(function(file)
      return vim.fn.filereadable(file) == 1
    end, context_group)
  )
end

---Get context contents for a buffer
---@param bufnr integer|nil Buffer number (nil for current buffer)
---@return table[] File contents with metadata
function M.get_context_contents(bufnr)
  local files = M.get_context_files(bufnr)
  local contents = {}

  for _, file_path in ipairs(files) do
    local content = utils.read_file_content(file_path)
    if content then
      table.insert(contents, {
        path = file_path,
        name = M.get_relative_path(file_path),
        content = content,
        filetype = vim.filetype.match({ filename = file_path }) or "",
        modified = vim.fn.getftime(file_path),
      })
    end
  end

  return contents
end

---Get project files
---@param bufnr integer|nil Buffer number (nil for current buffer)
---@return string[] project_files List of project files
function M.get_project_files(bufnr)
  local file_path = get_current_filepath(bufnr)
  if not file_path then
    vim.notify("No valid file path found", vim.log.levels.WARN)
    return {}
  end

  local root = M.find_root(file_path)
  local ignore_patterns = config.get().import_prefs.ignore_patterns or {}

  -- Get all project files
  local all_files = M.get_files(root)

  -- Filter out ignored files
  return vim.tbl_filter(function(file)
    -- Check ignore patterns
    for _, pattern in ipairs(ignore_patterns) do
      if file:match(pattern) then
        return false
      end
    end
    -- Ensure file is readable
    return vim.fn.filereadable(file) == 1
  end, all_files)
end


---Add file to context group
---@param file string File to add
---@param target_bufnr integer|nil Target buffer number
---@return boolean success
function M.add_context_file(file, target_bufnr)
  local target_path = get_current_filepath(target_bufnr) or file
  if not target_path then
    vim.notify("Cannot add to context: No valid file path found", vim.log.levels.ERROR)
    return false
  end

  local root = M.find_root(target_path)
  local store = storage.get_storage(root)

  -- Ensure file exists and is readable
  if not utils.read_file_content(file) then
    vim.notify("Cannot add to context: File not readable: " .. file, vim.log.levels.ERROR)
    return false
  end

  -- Get current context group
  local context_group = store:get(target_path) or {}

  -- Check if file already in context group
  for _, existing_file in ipairs(context_group) do
    if existing_file == file then
      vim.notify("File already in context group: " .. file, vim.log.levels.INFO)
      return false
    end
  end

  -- Add file to context group
  table.insert(context_group, file)

  -- Save updated context group
  local success = store:set(target_path, context_group)

  -- Trigger configured callback function
  local cfg = config.get()
  if success and cfg.on_context_change then
    cfg.on_context_change()
  end

  return success
end


---Remove file from context group
---@param file string File to remove
---@param target_bufnr integer|nil Target buffer number
---@return boolean success
function M.remove_context_file(file, target_bufnr)
  local target_path = get_current_filepath(target_bufnr)
  if not target_path then
    vim.notify("Cannot remove from context: No valid file path found", vim.log.levels.ERROR)
    return false
  end

  local root = M.find_root(target_path)
  local store = storage.get_storage(root)

  -- Get current context group
  local context_group = store:get(target_path)
  if not context_group then
    return false
  end

  -- Find and remove file
  local removed = false
  for i, existing_file in ipairs(context_group) do
    if existing_file == file then
      table.remove(context_group, i)
      removed = true
      break
    end
  end

  if not removed then
    return false
  end

  -- Save updated context group
  local success = store:set(target_path, context_group)

  -- Trigger configured callback function
  local cfg = config.get()
  if success and cfg.on_context_change then
    cfg.on_context_change()
  end

  return success
end

---Clear context group
---@param target_bufnr integer|nil Target buffer number
---@return boolean success
function M.clear_context_group(target_bufnr)
  local target_path = get_current_filepath(target_bufnr)
  if not target_path then
    vim.notify("Cannot clear context: No valid file path found", vim.log.levels.ERROR)
    return false
  end

  local root = M.find_root(target_path)
  local store = storage.get_storage(root)

  -- Remove context group
  local success = store:delete(target_path)

  -- Trigger configured callback function
  local cfg = config.get()
  if success and cfg.on_context_change then
    cfg.on_context_change()
  end

  return success
end

---Get context statistics
---@param target_bufnr integer|nil Target buffer number
---@return table stats Statistics
function M.get_context_stats(target_bufnr)
  local files = M.get_context_files(target_bufnr)
  local stats = {
    total_files = #files,
    total_lines = 0,
    by_type = {},
    total_size = 0,
  }

  for _, file in ipairs(files) do
    -- Get file type
    local ft = vim.filetype.match({ filename = file }) or "unknown"
    stats.by_type[ft] = (stats.by_type[ft] or 0) + 1

    -- Get file content
    local content = utils.read_file_content(file)
    if content then
      -- Count lines
      local lines = vim.split(content, "\n")
      stats.total_lines = stats.total_lines + #lines
      -- Calculate size
      stats.total_size = stats.total_size + #content
    end
  end

  return stats
end

---Get project files and directories for picker
---@param bufnr integer|nil Buffer number (nil for current buffer)
---@return string[] items List of project files and directories
function M.get_project_items(bufnr)
  local file_path = get_current_filepath(bufnr)
  if not file_path then
    vim.notify("No valid file path found", vim.log.levels.WARN)
    return {}
  end

  local root = M.find_root(file_path)
  local ignore_patterns = config.get().import_prefs.ignore_patterns or {}

  -- Use efficient external tools to get all files and directories
  local all_items = project.get_files_and_directories(root)

  -- Filter out ignored items
  if #ignore_patterns == 0 then
    return all_items
  end

  return vim.tbl_filter(function(item)
    -- Check ignore patterns
    for _, pattern in ipairs(ignore_patterns) do
      if item:match(pattern) then
        return false
      end
    end
    return true
  end, all_items)
end

---Get all files in a directory recursively
---@param dir_path string Directory path
---@return string[] files List of files in directory
function M.get_directory_files(dir_path)
  if vim.fn.isdirectory(dir_path) ~= 1 then
    return {}
  end

  local ignore_patterns = config.get().import_prefs.ignore_patterns or {}
  local files = {}

  -- Use fd if available (fastest for directory scanning)
  if vim.fn.executable("fd") == 1 then
    local cmd = string.format("fd -t f . %s", vim.fn.shellescape(dir_path))
    local handle = io.popen(cmd)
    if handle then
      local result = handle:read("*a")
      handle:close()
      local all_files = vim.split(result, "\n")
      
      for _, file in ipairs(all_files) do
        if file ~= "" then
          table.insert(files, file)
        end
      end
    end
  else
    -- Fallback to find
    local cmd = string.format("find %s -type f", vim.fn.shellescape(dir_path))
    local handle = io.popen(cmd)
    if handle then
      local result = handle:read("*a")
      handle:close()
      local all_files = vim.split(result, "\n")
      
      for _, file in ipairs(all_files) do
        if file ~= "" then
          table.insert(files, file)
        end
      end
    end
  end

  -- Filter out ignored files if patterns exist
  if #ignore_patterns == 0 then
    return files
  end

  return vim.tbl_filter(function(file)
    for _, pattern in ipairs(ignore_patterns) do
      if file:match(pattern) then
        return false
      end
    end
    return true
  end, files)
end

---Add multiple files to context group
---@param files string[] Files to add
---@param target_bufnr integer|nil Target buffer number
---@return table result {success: boolean, added: number, skipped: number, errors: string[]}
function M.add_multiple_context_files(files, target_bufnr)
  local result = {
    success = false,
    added = 0,
    skipped = 0,
    errors = {}
  }

  if #files == 0 then
    table.insert(result.errors, "No files provided")
    return result
  end

  local target_path = get_current_filepath(target_bufnr)
  if not target_path then
    table.insert(result.errors, "No valid file path found")
    return result
  end

  local root = M.find_root(target_path)
  local store = storage.get_storage(root)

  -- Get current context group
  local context_group = store:get(target_path) or {}
  local context_set = {}
  for _, file in ipairs(context_group) do
    context_set[file] = true
  end

  -- Process each file
  for _, file in ipairs(files) do
    -- Check if file is readable
    if not utils.read_file_content(file) then
      table.insert(result.errors, "File not readable: " .. file)
    elseif context_set[file] then
      result.skipped = result.skipped + 1
    else
      table.insert(context_group, file)
      context_set[file] = true
      result.added = result.added + 1
    end
  end

  -- Save updated context group if any files were added
  if result.added > 0 then
    local success = store:set(target_path, context_group)
    if success then
      result.success = true
      -- Trigger configured callback function
      local cfg = config.get()
      if cfg.on_context_change then
        cfg.on_context_change()
      end
    else
      table.insert(result.errors, "Failed to save context group")
    end
  else
    result.success = true
  end

  return result
end

return M
