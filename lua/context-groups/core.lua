-- lua/context-groups/core.lua
-- Consolidates core functionality from core/init.lua, core/storage.lua, and core/project.lua

local config = require("context-groups.config")
local utils = require("context-groups.utils")

local M = {}

-- Private Storage implementation (from core/storage.lua)
---@class Storage
---@field path string Storage file path
---@field data table Data cache
local Storage = {}
Storage.__index = Storage

---Create new storage instance
---@param component string Component identifier
---@return Storage
function Storage.new(component)
  local self = setmetatable({}, Storage)
  self.path = config.get_storage_path(component)
  self.data = {}
  self:load()
  return self
end

---Load data from storage file
---@return boolean success
function Storage:load()
  local content = utils.read_file_content(self.path)
  if not content then
    return false
  end

  local ok, data = pcall(vim.fn.json_decode, content)
  if ok and data then
    self.data = data
    return true
  end

  return false
end

---Save data to storage file
---@return boolean success
function Storage:save()
  local ok, encoded = pcall(vim.fn.json_encode, self.data)
  if not ok then
    return false
  end

  return utils.write_file_content(self.path, encoded)
end

---Get value for key
---@param key string
---@return any value
function Storage:get(key)
  return self.data[key]
end

---Set value for key
---@param key string
---@param value any
---@return boolean success
function Storage:set(key, value)
  self.data[key] = value
  return self:save()
end

---Delete key
---@param key string
---@return boolean success
function Storage:delete(key)
  self.data[key] = nil
  return self:save()
end

---Clear all data
---@return boolean success
function Storage:clear()
  self.data = {}
  return self:save()
end

-- Project utilities (from core/project.lua)

---Cache for project roots
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

-- Core functionality (from core/init.lua)

-- Storage instance cache
---@type table<string, Storage>
local storage_cache = {}

---Get storage instance for a project
---@param root string Project root directory
---@return Storage
local function get_storage(root)
  if not storage_cache[root] then
    storage_cache[root] = Storage.new("context")
  end
  return storage_cache[root]
end

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
  local storage = get_storage(root)

  -- Get context group for current file
  local context_group = storage:get(file_path) or {}

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
  local storage = get_storage(root)

  -- Ensure file exists and is readable
  if not utils.read_file_content(file) then
    vim.notify("Cannot add to context: File not readable: " .. file, vim.log.levels.ERROR)
    return false
  end

  -- Get current context group
  local context_group = storage:get(target_path) or {}

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
  local success = storage:set(target_path, context_group)

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
  local storage = get_storage(root)

  -- Get current context group
  local context_group = storage:get(target_path)
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
  local success = storage:set(target_path, context_group)

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
  local storage = get_storage(root)

  -- Remove context group
  local success = storage:delete(target_path)

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

-- Export functionality (simplified from core/export.lua)
M.export = {}

-- Check if path should be excluded
---@param path string Path to check
---@param exclude_patterns string[] Exclude patterns
---@return boolean
local function should_exclude(path, exclude_patterns)
  -- Normalize path format, remove leading ./ and trailing /
  path = path:gsub("^%./", ""):gsub("/$", "")

  for _, pattern in ipairs(exclude_patterns) do
    -- Check if any part of path matches exclude pattern
    for part in path:gmatch("[^/]+") do
      if part:match(pattern) then
        return true
      end
    end
    -- Also check complete path
    if path:match(pattern) then
      return true
    end
  end
  return false
end

-- Generate project tree structure
---@param root string Project root directory
---@param paths string[] Paths to include
---@param depth number Maximum depth
---@return string tree Tree structure text
local function generate_tree_structure(root, paths, depth)
  local exclude_patterns = config.get().export.exclude_patterns
  local tree = { "." }

  -- Create a map to store all directories that need to be shown
  local dir_map = {}

  -- Preprocess each path to ensure all necessary parent directories are included
  for _, file_path in ipairs(paths) do
    -- Check if file path should be excluded
    if not should_exclude(file_path, exclude_patterns) then
      local current_path = ""
      for part in file_path:gmatch("[^/]+") do
        current_path = current_path == "" and part or (current_path .. "/" .. part)
        -- Only add to dir_map if path shouldn't be excluded
        if not should_exclude(current_path, exclude_patterns) then
          dir_map[current_path] = true
        end
      end
    end
  end

  local function should_include(path)
    -- Normalize path
    local normalized_path = path:gsub("^%./", "")
    -- First check if should be excluded
    if should_exclude(normalized_path, exclude_patterns) then
      return false
    end
    -- Then check if in include list
    return dir_map[normalized_path] ~= nil
  end

  local function add_to_tree(path, level, prefix)
    if level > depth then
      return
    end

    -- Get all items in current directory
    local handle = io.popen(string.format("ls -a %s", vim.fn.shellescape(root .. "/" .. path)))
    if not handle then
      return
    end

    local items = {}
    for item in handle:lines() do
      if item ~= "." and item ~= ".." then
        local full_path = path == "." and item or (path .. "/" .. item)
        -- Use improved filtering logic
        if not should_exclude(full_path, exclude_patterns) and should_include(full_path) then
          table.insert(items, item)
        end
      end
    end
    handle:close()
    table.sort(items)

    for i, item in ipairs(items) do
      local is_last = (i == #items)
      local current_prefix = prefix .. (is_last and "└── " or "├── ")
      local next_prefix = prefix .. (is_last and "    " or "│   ")
      local full_path = path == "." and item or (path .. "/" .. item)

      table.insert(tree, current_prefix .. item)

      if vim.fn.isdirectory(root .. "/" .. full_path) == 1 then
        add_to_tree(full_path, level + 1, next_prefix)
      end
    end
  end

  add_to_tree(".", 1, "")
  return table.concat(tree, "\n")
end

---Generate git staged diff
---@param root string Project root directory
---@return string? diff Git diff output
local function get_git_staged_diff(root)
  if not config.get().export.show_git_changes then
    return nil
  end

  -- Check if in git repository
  local check_git =
    io.popen(string.format("cd %s && git rev-parse --is-inside-work-tree 2>/dev/null", vim.fn.shellescape(root)))
  if not check_git then
    return nil
  end
  local is_git = check_git:read("*a")
  check_git:close()
  if is_git == "" then
    return nil
  end

  local result = { "<git_staged_changes>" }

  -- Get staged file status
  local status_handle = io.popen(string.format("cd %s && git diff --staged --name-status", vim.fn.shellescape(root)))
  if status_handle then
    local status = status_handle:read("*a")
    status_handle:close()
    if status ~= "" then
      table.insert(result, "# Staged Files:")
      table.insert(result, status)

      -- Get detailed changes
      local diff_handle = io.popen(string.format("cd %s && git diff --staged --color=never", vim.fn.shellescape(root)))
      if diff_handle then
        local diff = diff_handle:read("*a")
        diff_handle:close()
        table.insert(result, "\n# Detailed Changes:")
        table.insert(result, diff)
      end
    else
      table.insert(result, "No staged changes")
    end
  end

  table.insert(result, "</git_staged_changes>")
  return table.concat(result, "\n")
end

---Process paths for export
---@param paths string[] Path list
---@return table[] contents File content list
local function process_paths(paths)
  local contents = {}
  local root = M.find_root(vim.fn.getcwd())
  local exclude_patterns = config.get().export.exclude_patterns

  local function process_directory(dir_path)
    local handle = io.popen(string.format("ls -a %s", vim.fn.shellescape(dir_path)))
    if handle then
      for item in handle:lines() do
        if item ~= "." and item ~= ".." then
          local item_path = dir_path .. "/" .. item
          local rel_path = vim.fn.fnamemodify(item_path, ":~:.")

          -- Use same exclusion logic
          if not should_exclude(rel_path, exclude_patterns) then
            if vim.fn.isdirectory(item_path) == 1 then
              process_directory(item_path)
            else
              local content = utils.read_file_content(item_path)
              if content then
                table.insert(contents, {
                  path = rel_path,
                  content = content,
                })
              end
            end
          end
        end
      end
      handle:close()
    end
  end

  for _, path in ipairs(paths) do
    -- Check if path should be excluded
    if not should_exclude(path, exclude_patterns) then
      local full_path = root .. "/" .. path
      if vim.fn.isdirectory(full_path) == 1 then
        process_directory(full_path)
      else
        local content = utils.read_file_content(full_path)
        if content then
          table.insert(contents, {
            path = path,
            content = content,
          })
        end
      end
    end
  end

  return contents
end

---Export project contents
---@param opts? table Export options
---@return table? result Export result
function M.export.export_contents(opts)
  opts = opts or {}
  local root = M.find_root(vim.fn.getcwd())

  -- Get paths to process
  local paths = opts.paths or {}
  if #paths == 0 and vim.env.PROCESS_PATHS then
    paths = vim.split(vim.env.PROCESS_PATHS, ":")
  end

  if #paths == 0 then
    vim.notify("No paths specified in PROCESS_PATHS", vim.log.levels.WARN)
    return nil
  end

  -- Build output content
  local result = {}

  -- Add project structure
  table.insert(result, string.format("Current Project Structure (depth: %d):", config.get().export.max_tree_depth))
  table.insert(result, "<project_structure>\n")
  table.insert(result, generate_tree_structure(root, paths, config.get().export.max_tree_depth))
  table.insert(result, "\n</project_structure>\n")

  -- Add Git diff
  local git_diff = get_git_staged_diff(root)
  if git_diff then
    table.insert(result, git_diff)
  end

  -- Add file contents
  table.insert(result, "---")
  table.insert(result, "All project files:")
  table.insert(result, "<code_base>\n")

  local contents = process_paths(paths)
  for _, file in ipairs(contents) do
    table.insert(result, string.format('<code path="%s">\n', file.path))
    table.insert(result, file.content)
    table.insert(result, "</code>\n")
  end

  table.insert(result, "</code_base>")

  return result
end

return M

