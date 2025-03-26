-- lua/context-groups/code2prompt/init.lua
-- Pure Lua implementation for copying buffer contents to clipboard

local M = {}

-- Format and copy the contents of open buffer files to clipboard
---@param llm_ctx LLMContext LLM context instance
---@return boolean success
function M.generate_prompt(llm_ctx)
  local buffer_files = llm_ctx:get_open_buffer_files()

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

  -- Get project root and project name
  local project_root = llm_ctx.root
  local project_name = vim.fn.fnamemodify(project_root, ":t")

  -- Begin building the output
  local output = {}
  table.insert(output, "---")
  table.insert(output, string.format("Here are some files I've selected from the project %s.", project_name))
  table.insert(output, "They are as follows:")

  -- Add file contents
  for _, rel_path in ipairs(buffer_files) do
    local abs_path = project_root .. "/" .. rel_path
    local content = M.read_file_content(abs_path)

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

-- Helper function to read file content
---@param filepath string File path
---@return string|nil content
function M.read_file_content(filepath)
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

return M
