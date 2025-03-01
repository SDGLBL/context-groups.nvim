-- lua/context-groups/utils/yaml_rust.lua
-- FFI interface to Rust YAML parser

local M = {}

-- Try to load FFI
local has_ffi, ffi = pcall(require, "ffi")
if not has_ffi then
  return nil -- FFI not available
end

-- Try to load JSON module for conversion
local json = vim.json
local has_json = (json ~= nil)

-- Only warn, don't return nil because we want to allow the minimal implementation fallback
if not has_json then
  vim.notify("YAML bridge requires vim.json for full functionality", vim.log.levels.WARN)
end

-- Try to load rust library
local lib = nil
local lib_loaded = false

-- Define FFI signatures
ffi.cdef([[
  char* yaml_parse(const char* input);
  char* yaml_encode(const char* input, int block_style);
  void free_string(char* ptr);
  size_t get_last_error(char* buffer, size_t size);
  void set_last_error(const char* error);
  const char* yaml_bridge_version();
]])

-- Find and load the library
local function load_library()
  if lib_loaded then
    return lib ~= nil
  end

  lib_loaded = true

  local lib_paths = {
    -- First check project-relative paths
    vim.fn.stdpath("config") .. "/context-groups/utils/lib/libyaml_bridge",
    vim.fn.stdpath("data") .. "/context-groups/utils/lib/libyaml_bridge",
    -- Then check absolute path
    "/Users/lijie/project/context-groups.nvim/lua/context-groups/utils/lib/libyaml_bridge",
    -- Then try current directory
    "./lua/context-groups/utils/lib/libyaml_bridge",
    -- Fallbacks without path
    "libyaml_bridge",
    "yaml_bridge",
  }

  -- Add OS-specific extensions
  local os_name = vim.loop.os_uname().sysname:lower()
  local extensions = {}

  if os_name:match("windows") then
    extensions = { ".dll" }
  elseif os_name:match("darwin") then
    extensions = { ".dylib", ".so" }
  else -- Linux and others
    extensions = { ".so" }
  end

  -- Try each path with each extension
  local errors = {}
  for _, path in ipairs(lib_paths) do
    for _, ext in ipairs(extensions) do
      local full_path = path .. ext
      local success, loaded_lib_or_error = pcall(ffi.load, full_path)
      if success then
        lib = loaded_lib_or_error
        vim.notify("Loaded YAML bridge library: " .. full_path, vim.log.levels.INFO)
        return true
      else
        table.insert(errors, "Failed to load " .. full_path .. ": " .. tostring(loaded_lib_or_error))
      end
    end
  end

  -- If we get here, we couldn't load the library
  vim.notify("Could not load YAML bridge library: " .. table.concat(errors, "\n"), vim.log.levels.WARN)
  return false
end

-- Get the last error message from the library
local function get_error()
  if not lib then
    return "Rust library not loaded"
  end

  local buf = ffi.new("char[1024]")
  lib.get_last_error(buf, 1024)
  return ffi.string(buf)
end

-- Parse YAML string to Lua table
---@param yaml_str string YAML content
---@return table|nil result Parsed content or nil on error
---@return string|nil error_message Error message in case of failure
function M.parse(yaml_str)
  -- Check if yaml_str is a string
  if type(yaml_str) ~= "string" then
    return nil, "Input must be a string"
  end

  -- Check if library is loaded
  if not load_library() then
    return nil, "Failed to load Rust YAML library"
  end

  -- Parse YAML using rust library
  local json_cstr = lib.yaml_parse(yaml_str)
  if json_cstr == nil then
    return nil, "YAML parsing failed: " .. get_error()
  end

  -- Convert returned C string to Lua string
  local json_str = ffi.string(json_cstr)

  -- Free the C string
  lib.free_string(json_cstr)

  -- Check for error
  if json_str:match('^{"error":"') then
    local error_msg = json_str:match('^{"error":"(.-)"') or "Unknown error"
    return nil, "YAML parsing failed: " .. error_msg
  end

  -- Parse JSON to Lua table
  local success, result = pcall(json.decode, json_str)
  if not success then
    return nil, "JSON decoding failed: " .. tostring(result)
  end

  return result
end

-- Encode Lua table to YAML string
---@param tbl table Table to encode
---@param block_style ?boolean Use block style for better readability
---@return string|nil yaml_str YAML string or nil on error
---@return string|nil error_message Error message in case of failure
function M.encode(tbl, block_style)
  -- Check if tbl is a table
  if type(tbl) ~= "table" then
    return nil, "Input must be a table"
  end

  -- Default to block style
  block_style = block_style ~= false

  -- Check if library is loaded
  if not load_library() then
    return nil, "Failed to load Rust YAML library"
  end

  -- Check if JSON module is available
  if not has_json or not json then
    return nil, "No JSON module available (vim.json required)"
  end

  -- Convert Lua table to JSON
  local success, json_str = pcall(json.encode, tbl)
  if not success then
    return nil, "JSON encoding failed: " .. tostring(json_str)
  end

  -- Encode JSON to YAML using rust library
  local yaml_cstr = lib.yaml_encode(json_str, block_style and 1 or 0)
  if yaml_cstr == nil then
    return nil, "YAML encoding failed: " .. get_error()
  end

  -- Convert returned C string to Lua string
  local yaml_str = ffi.string(yaml_cstr)

  -- Free the C string
  lib.free_string(yaml_cstr)

  -- Check for error
  if yaml_str:match('^{"error":"') then
    local error_msg = yaml_str:match('^{"error":"(.-)"') or "Unknown error"
    return nil, "YAML encoding failed: " .. error_msg
  end

  return yaml_str
end

-- Check if the Rust library is available
---@return boolean is_available
function M.is_available()
  return load_library()
end

-- Get version information about the Rust library
---@return string|nil version_info
function M.version()
  if not load_library() then
    return nil
  end

  local version_cstr = lib.yaml_bridge_version()
  if version_cstr == nil then
    return nil
  end

  -- No need to free this string as it's a static const
  return ffi.string(version_cstr)
end

-- For compatibility with the current yaml.lua API
M.eval = M.parse
M.dump = function(tbl)
  print(M.encode(tbl, true))
end

return M
