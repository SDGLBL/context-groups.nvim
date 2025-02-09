-- lua/context-groups/core/export.lua

local config = require("context-groups.config")
local project = require("context-groups.core.project")

local M = {}

-- Git 相关函数
---@param root string 项目根目录
---@return string? diff Git diff 输出
local function get_git_staged_diff(root)
  if not config.get().export.show_git_changes then
    return nil
  end

  -- 检查是否在 git 仓库中
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

  -- 获取暂存区文件状态
  local status_handle = io.popen(string.format("cd %s && git diff --staged --name-status", vim.fn.shellescape(root)))
  if status_handle then
    local status = status_handle:read("*a")
    status_handle:close()
    if status ~= "" then
      table.insert(result, "# Staged Files:")
      table.insert(result, status)

      -- 获取详细变更
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

-- 检查路径是否应该被排除
---@param path string 待检查的路径
---@param exclude_patterns string[] 排除模式列表
---@return boolean
local function should_exclude(path, exclude_patterns)
  -- 规范化路径格式，移除开头的 ./ 和结尾的 /
  path = path:gsub("^%./", ""):gsub("/$", "")

  for _, pattern in ipairs(exclude_patterns) do
    -- 检查路径的任何部分是否匹配排除模式
    for part in path:gmatch("[^/]+") do
      if part:match(pattern) then
        return true
      end
    end
    -- 同时也检查完整路径
    if path:match(pattern) then
      return true
    end
  end
  return false
end

-- 生成项目树结构
---@param root string 项目根目录
---@param paths string[] 要包含的文件路径
---@param depth number 最大深度
---@return string tree 树结构文本
local function generate_tree_structure(root, paths, depth)
  local exclude_patterns = config.get().export.exclude_patterns
  local tree = { "." }

  -- 创建一个映射来存储所有需要显示的目录
  local dir_map = {}

  -- 对每个路径进行预处理，确保所有必要的父目录都被包含
  for _, file_path in ipairs(paths) do
    -- 检查文件路径是否应该被排除
    if not should_exclude(file_path, exclude_patterns) then
      local current_path = ""
      for part in file_path:gmatch("[^/]+") do
        current_path = current_path == "" and part or (current_path .. "/" .. part)
        -- 只有当路径不应被排除时才添加到 dir_map
        if not should_exclude(current_path, exclude_patterns) then
          dir_map[current_path] = true
        end
      end
    end
  end

  local function should_include(path)
    -- 规范化路径
    local normalized_path = path:gsub("^%./", "")
    -- 首先检查是否应该排除
    if should_exclude(normalized_path, exclude_patterns) then
      return false
    end
    -- 然后检查是否在包含列表中
    return dir_map[normalized_path] ~= nil
  end

  local function add_to_tree(path, level, prefix)
    if level > depth then
      return
    end

    -- 获取当前目录下的所有项目
    local handle = io.popen(string.format("ls -a %s", vim.fn.shellescape(root .. "/" .. path)))
    if not handle then
      return
    end

    local items = {}
    for item in handle:lines() do
      if item ~= "." and item ~= ".." then
        local full_path = path == "." and item or (path .. "/" .. item)
        -- 使用改进的过滤逻辑
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

-- 读取文件内容
---@param file string 文件路径
---@return string? content 文件内容
local function read_file_content(file)
  local handle = io.open(file, "r")
  if not handle then
    return nil
  end
  local content = handle:read("*a")
  handle:close()
  return content
end

-- 处理要处理的路径
---@param paths string[] 路径列表
---@return table[] contents 文件内容列表
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

          -- 使用相同的排除逻辑
          if not should_exclude(rel_path, exclude_patterns) then
            if vim.fn.isdirectory(item_path) == 1 then
              process_directory(item_path)
            else
              local content = read_file_content(item_path)
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
    -- 检查路径是否应该被排除
    if not should_exclude(path, exclude_patterns) then
      local full_path = root .. "/" .. path
      if vim.fn.isdirectory(full_path) == 1 then
        process_directory(full_path)
      else
        local content = read_file_content(full_path)
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

-- 导出函数
---@param opts? table 导出选项
---@return table? result 导出结果
function M.export_contents(opts)
  opts = opts or {}
  local root = project.find_root(vim.fn.getcwd())

  -- 获取要处理的路径
  local paths = opts.paths or {}
  if #paths == 0 and vim.env.PROCESS_PATHS then
    paths = vim.split(vim.env.PROCESS_PATHS, ":")
  end

  if #paths == 0 then
    vim.notify("No paths specified in PROCESS_PATHS", vim.log.levels.WARN)
    return nil
  end

  -- 构建输出内容
  local result = {}

  -- 添加项目结构
  table.insert(result, string.format("Current Project Structure (depth: %d):", config.get().export.max_tree_depth))
  table.insert(result, "<project_structure>\n")
  table.insert(result, generate_tree_structure(root, paths, config.get().export.max_tree_depth))
  table.insert(result, "\n</project_structure>\n")

  -- 添加 Git 差异
  local git_diff = get_git_staged_diff(root)
  if git_diff then
    table.insert(result, git_diff)
  end

  -- 添加文件内容
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

  -- 创建新buffer显示结果
  -- local buf = vim.api.nvim_create_buf(true, true)
  -- vim.api.nvim_buf_set_lines(buf, 0, -1, true, vim.split(table.concat(result, "\n"), "\n"))
  --
  -- -- 设置buffer选项
  -- vim.api.nvim_buf_set_option(buf, "modifiable", false)
  -- vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  --
  -- -- 在新窗口中显示
  -- vim.cmd("vsplit")
  -- vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)

  return result
  -- return table.concat(result, "\n")
end

return M
