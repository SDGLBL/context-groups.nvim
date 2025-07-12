-- lua/context-groups/export.lua
-- Export functionality extracted from core.lua

local config = require("context-groups.config")
local utils = require("context-groups.utils")
local project = require("context-groups.project")

local M = {}

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
  local root = project.find_root(vim.fn.getcwd())
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
function M.export_contents(opts)
  opts = opts or {}
  local root = project.find_root(vim.fn.getcwd())

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