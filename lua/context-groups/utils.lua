-- lua/context-groups/utils.lua
-- Consolidates utility functions

local Utils = {}

-- File system utilities
---@param filepath string File path
---@return string|nil content
function Utils.read_file_content(filepath)
  if not filepath or filepath == "" then
    return nil
  end

  -- Check if file exists and is readable
  if vim.fn.filereadable(filepath) ~= 1 then
    return nil
  end

  -- Read file content
  local content = table.concat(vim.fn.readfile(filepath), "\n")
  if content == "" then
    return nil
  end

  return content
end

---@param filepath string File path
---@param content string Content to write
---@return boolean success
function Utils.write_file_content(filepath, content)
  local lines = vim.split(content, "\n")
  return vim.fn.writefile(lines, filepath) == 0
end

-- Path utilities
---@param path string File path
---@return string relative_path
function Utils.get_relative_path(path, root)
  -- Ensure path is absolute
  local abs_path = vim.fn.fnamemodify(path, ":p")

  -- If path starts with root, remove root part
  if root and vim.startswith(abs_path, root) then
    -- Remove root dir and leading slash
    return abs_path:sub(#root + 2)
  end

  -- If path not in project, return original path
  return vim.fn.fnamemodify(path, ":~:.")
end

return Utils
