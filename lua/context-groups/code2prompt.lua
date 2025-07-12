-- lua/context-groups/code2prompt.lua
-- Pure Lua implementation for copying buffer contents to clipboard

local core = require("context-groups.core")
local utils = require("context-groups.utils")

local M = {}

-- Get all open buffer file paths
---@return string[] file_paths, string root_path
local function get_open_buffer_files()
  local root = core.find_root(vim.fn.expand("%:p"))
  local files = {}
  local seen = {}

  -- Get currently open files
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
      local path = vim.api.nvim_buf_get_name(bufnr)
      if path and path ~= "" and vim.fn.filereadable(path) == 1 then
        path = vim.fn.fnamemodify(path, ":p")
        if vim.startswith(path, root) then
          path = path:sub(#root + 2) -- +2 to remove the trailing slash
          seen[path] = true
          table.insert(files, path)

          -- Get context group files for this buffer
          local context_files = core.get_context_files(bufnr, { relative = true })
          for _, context_file in ipairs(context_files) do
            if not seen[context_file] then
              seen[context_file] = true
              table.insert(files, context_file)
            end
          end
        end
      end
    end
  end

  return files, root
end

-- Format and copy the contents of open buffer files to clipboard
---@return boolean success
function M.generate_prompt()
  local buffer_files, project_root = get_open_buffer_files()

  if #buffer_files == 0 then
    vim.notify("No valid open buffer files found", vim.log.levels.ERROR)
    return false
  end

  -- Check if any buffers are modified
  local has_modified = false
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].modified then
      has_modified = true
      break
    end
  end

  if has_modified then
    vim.notify("Please save all modified buffers before generating content", vim.log.levels.WARN)
    return false
  end

  -- Get project name
  local project_name = vim.fn.fnamemodify(project_root, ":t")

  -- Begin building the output
  local output = {}
  table.insert(output, "---")
  table.insert(output, string.format("Here are some files I've selected from the project %s.", project_name))
  table.insert(output, "They are as follows:")

  -- Add file contents
  for _, rel_path in ipairs(buffer_files) do
    local abs_path = project_root .. "/" .. rel_path
    local content = utils.read_file_content(abs_path)

    if content then
      table.insert(output, "```")
      table.insert(output, abs_path)
      table.insert(output, content)
      table.insert(output, "```")
      table.insert(output, "") -- Add empty line between files
    end
  end

  -- Combine all text and copy to clipboard
  local final_output = table.concat(output, "\n")
  vim.fn.setreg("+", final_output)

  vim.notify(string.format("Contents of %d files copied to clipboard", #buffer_files), vim.log.levels.INFO)
  return true
end

return M