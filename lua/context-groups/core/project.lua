-- lua/context-groups/core/project.lua

local config = require("context-groups.config")

local M = {}

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
	-- 确保路径是绝对路径
	local abs_path = vim.fn.fnamemodify(path, ":p")

	-- 如果路径以根目录开头，移除根目录部分
	if vim.startswith(abs_path, root) then
		-- 去掉根目录和开头的斜杠
		return abs_path:sub(#root + 2)
	end

	-- 如果路径不在项目内，返回原始路径
	return vim.fn.fnamemodify(path, ":~:.")
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

return M
