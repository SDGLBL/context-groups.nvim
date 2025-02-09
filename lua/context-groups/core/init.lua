-- lua/context-groups/core/init.lua

local config = require("context-groups.config")
local Storage = require("context-groups.core.storage")
local project = require("context-groups.core.project")

local M = {}

-- 存储实例的缓存
local storage_cache = {}

---获取指定项目的存储实例
---@param root string 项目根目录
---@return Storage
local function get_storage(root)
	if not storage_cache[root] then
		storage_cache[root] = Storage.new("context")
	end
	return storage_cache[root]
end

---使用系统命令读取文件内容
---@param filepath string 文件路径
---@return string|nil content 文件内容或nil
local function read_file_content(filepath)
	if not filepath or filepath == "" then
		return nil
	end

	-- 检查文件是否存在且可读
	if vim.fn.filereadable(filepath) ~= 1 then
		return nil
	end

	-- 使用 cat 命令读取文件内容
	local cmd = string.format("cat %s", vim.fn.shellescape(filepath))
	local handle = io.popen(cmd)
	if not handle then
		return nil
	end

	local content = handle:read("*a")
	handle:close()

	return content
end

---获取当前文件路径
---@param bufnr number|nil Buffer number
---@return string|nil filepath 文件路径或nil
local function get_current_filepath(bufnr)
	-- 如果提供了 buffer number，先尝试从中获取路径
	if bufnr then
		local path = vim.api.nvim_buf_get_name(bufnr)
		if path and path ~= "" and vim.fn.filereadable(path) == 1 then
			return path
		end
	end

	-- 尝试从当前窗口获取文件路径
	local current_buf = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(current_buf)
	if path and path ~= "" and vim.fn.filereadable(path) == 1 then
		return path
	end

	-- 如果还是失败，尝试获取当前工作目录
	local cwd = vim.fn.getcwd()
	if cwd and cwd ~= "" then
		return cwd
	end

	return nil
end

---获取指定buffer的上下文组
---@param bufnr integer|nil Buffer number (nil for current buffer)
---@return string[] context_files 上下文文件列表
function M.get_context_files(bufnr)
	local file_path = get_current_filepath(bufnr)
	if not file_path then
		vim.notify("No valid file path found", vim.log.levels.WARN)
		return {}
	end

	local root = project.find_root(file_path)
	local storage = get_storage(root)

	-- 获取当前文件的上下文组
	local context_group = storage:get(file_path) or {}

	-- 过滤掉不存在的文件
	return vim.tbl_filter(function(file)
		return vim.fn.filereadable(file) == 1
	end, context_group)
end

---获取指定buffer的所有文件内容
---@param bufnr integer|nil Buffer number (nil for current buffer)
---@return table[] File contents with metadata
function M.get_context_contents(bufnr)
	local files = M.get_context_files(bufnr)
	local contents = {}

	for _, file_path in ipairs(files) do
		local content = read_file_content(file_path)
		if content then
			table.insert(contents, {
				path = file_path,
				name = project.get_relative_path(file_path),
				content = content,
				filetype = vim.filetype.match({ filename = file_path }) or "",
				modified = vim.fn.getftime(file_path),
			})
		end
	end

	return contents
end

---获取项目中的所有文件
---@param bufnr integer|nil Buffer number (nil for current buffer)
---@return string[] project_files 项目文件列表
function M.get_project_files(bufnr)
	local file_path = get_current_filepath(bufnr)
	if not file_path then
		vim.notify("No valid file path found", vim.log.levels.WARN)
		return {}
	end

	local root = project.find_root(file_path)
	local ignore_patterns = config.get().import_prefs.ignore_patterns or {}

	-- 获取所有项目文件
	local all_files = project.get_files(root)

	-- 过滤掉被忽略的文件
	return vim.tbl_filter(function(file)
		-- 检查忽略模式
		for _, pattern in ipairs(ignore_patterns) do
			if file:match(pattern) then
				return false
			end
		end
		-- 确保文件可读
		return vim.fn.filereadable(file) == 1
	end, all_files)
end

---添加文件到上下文组
---@param file string 要添加的文件路径
---@param target_bufnr integer|nil 目标buffer number
---@return boolean success 是否成功
function M.add_context_file(file, target_bufnr)
	local target_path = get_current_filepath(target_bufnr) or file
	if not target_path then
		vim.notify("Cannot add to context: No valid file path found", vim.log.levels.ERROR)
		return false
	end

	local root = project.find_root(target_path)
	local storage = get_storage(root)

	-- 确保文件存在且可读
	if not read_file_content(file) then
		vim.notify("Cannot add to context: File not readable: " .. file, vim.log.levels.ERROR)
		return false
	end

	-- 获取当前上下文组
	local context_group = storage:get(target_path) or {}

	-- 检查文件是否已在上下文组中
	for _, existing_file in ipairs(context_group) do
		if existing_file == file then
			vim.notify("File already in context group: " .. file, vim.log.levels.INFO)
			return false
		end
	end

	-- 添加文件到上下文组
	table.insert(context_group, file)

	-- 保存更新后的上下文组
	local success = storage:set(target_path, context_group)

	-- 触发配置的回调函数
	local cfg = config.get()
	if success and cfg.on_context_change then
		cfg.on_context_change()
	end

	return success
end

---从上下文组中移除文件
---@param file string 要移除的文件路径
---@param target_bufnr integer|nil 目标buffer number
---@return boolean success 是否成功
function M.remove_context_file(file, target_bufnr)
	local target_path = get_current_filepath(target_bufnr)
	if not target_path then
		vim.notify("Cannot remove from context: No valid file path found", vim.log.levels.ERROR)
		return false
	end

	local root = project.find_root(target_path)
	local storage = get_storage(root)

	-- 获取当前上下文组
	local context_group = storage:get(target_path)
	if not context_group then
		return false
	end

	-- 查找并移除文件
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

	-- 保存更新后的上下文组
	local success = storage:set(target_path, context_group)

	-- 触发配置的回调函数
	local cfg = config.get()
	if success and cfg.on_context_change then
		cfg.on_context_change()
	end

	return success
end

---清除指定buffer的上下文组
---@param target_bufnr integer|nil 目标buffer number
---@return boolean success 是否成功
function M.clear_context_group(target_bufnr)
	local target_path = get_current_filepath(target_bufnr)
	if not target_path then
		vim.notify("Cannot clear context: No valid file path found", vim.log.levels.ERROR)
		return false
	end

	local root = project.find_root(target_path)
	local storage = get_storage(root)

	-- 移除上下文组
	local success = storage:delete(target_path)

	-- 触发配置的回调函数
	local cfg = config.get()
	if success and cfg.on_context_change then
		cfg.on_context_change()
	end

	return success
end

---获取上下文组的统计信息
---@param target_bufnr integer|nil 目标buffer number
---@return table stats 统计信息
function M.get_context_stats(target_bufnr)
	local files = M.get_context_files(target_bufnr)
	local stats = {
		total_files = #files,
		total_lines = 0,
		by_type = {},
		total_size = 0,
	}

	for _, file in ipairs(files) do
		-- 获取文件类型
		local ft = vim.filetype.match({ filename = file }) or "unknown"
		stats.by_type[ft] = (stats.by_type[ft] or 0) + 1

		-- 获取文件内容
		local content = read_file_content(file)
		if content then
			-- 计算行数
			local lines = vim.split(content, "\n")
			stats.total_lines = stats.total_lines + #lines
			-- 计算大小
			stats.total_size = stats.total_size + #content
		end
	end

	return stats
end

return M
