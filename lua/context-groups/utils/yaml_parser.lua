-- lua/context-groups/utils/yaml_parser.lua
-- YAML parser wrapper for context-groups.nvim

local yaml = require("context-groups.utils.yaml")

local M = {}

-- Parse YAML content to Lua table
---@param content string YAML content
---@return table? parsed_content
function M.parse(content)
  -- Check if content is empty or not a string
  if not content or type(content) ~= "string" or content == "" then
    return nil
  end
  
  local ok, result = pcall(yaml.eval, content)
  if not ok then
    vim.notify("Error parsing YAML: " .. tostring(result), vim.log.levels.ERROR)
    return nil
  end
  
  return result
end

-- Encode Lua table to YAML string
---@param tbl table Table to encode
---@return string yaml_string
function M.encode(tbl)
  if type(tbl) ~= "table" then
    vim.notify("Cannot encode non-table to YAML", vim.log.levels.ERROR)
    return ""
  end
  
  local ok, result = pcall(yaml.encode, tbl)
  if not ok then
    vim.notify("Error encoding to YAML: " .. tostring(result), vim.log.levels.ERROR)
    return ""
  end
  
  return result
end

-- Read YAML file and parse contents
---@param filepath string Path to YAML file
---@return table? parsed_content
function M.read_file(filepath)
  -- Check if file exists and is readable
  if vim.fn.filereadable(filepath) ~= 1 then
    vim.notify("YAML file not readable: " .. filepath, vim.log.levels.ERROR)
    return nil
  end
  
  -- Read file content
  local content = table.concat(vim.fn.readfile(filepath), "\n")
  if content == "" then
    return {}
  end
  
  return M.parse(content)
end

-- Write table to YAML file
---@param filepath string Path to YAML file
---@param data table Data to write
---@return boolean success
function M.write_file(filepath, data)
  local yaml_content = M.encode(data)
  if yaml_content == "" then
    return false
  end
  
  local lines = vim.split(yaml_content, "\n")
  return vim.fn.writefile(lines, filepath) == 0
end

-- Check if a file is a YAML file by extension
---@param filepath string Path to check
---@return boolean is_yaml
function M.is_yaml_file(filepath)
  return filepath:match("%.ya?ml$") ~= nil
end

-- Validate YAML data against a schema
---@param data table Data to validate
---@param schema table Schema definition
---@return boolean valid, string? error_message
function M.validate(data, schema)
  -- Basic validation only - can be extended with more complex schema validation
  if not data or type(data) ~= "table" then
    return false, "Data is not a valid table"
  end
  
  -- Just a simple existence check for required fields
  for key, field_type in pairs(schema) do
    if data[key] == nil then
      return false, "Missing required field: " .. key
    end
    
    if type(data[key]) ~= field_type then
      return false, "Field " .. key .. " should be of type " .. field_type .. 
                   " but is " .. type(data[key])
    end
  end
  
  return true
end

return M
