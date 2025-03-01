-- lua/context-groups/utils/yaml.lua
-- YAML parser facade that selects between Rust and pure Lua implementations

local config = require("context-groups.config")

-- Try to load the Rust implementation first
local yaml_rust = require("context-groups.utils.yaml_rust")

-- Default to pure Lua implementation as fallback
local yaml_pure = require("context-groups.utils.yaml_pure")

local M = {}

-- Check if Rust implementation should be used
local function use_rust()
  local cfg = config.get()
  
  -- Honor explicit user configuration if available
  if cfg.yaml_parser and cfg.yaml_parser.use_rust ~= nil then
    return cfg.yaml_parser.use_rust
  end
  
  -- Otherwise use Rust if available
  return yaml_rust and yaml_rust.is_available()
end

-- Get the active YAML implementation
local function get_impl()
  if use_rust() then
    return yaml_rust
  else
    return yaml_pure
  end
end

-- Parse YAML string to Lua table
---@param yaml_str string YAML content
---@return table|nil result Parsed content or nil on error
---@return string|nil error_message Error message in case of failure
function M.parse(yaml_str)
  local impl = get_impl()
  local result, err = impl.parse(yaml_str)
  
  -- Log operation if debug is enabled
  local cfg = config.get()
  if cfg.yaml_parser and cfg.yaml_parser.debug then
    local impl_name = (impl == yaml_rust) and "Rust" or "Lua"
    vim.notify(
      string.format("[YAML] Parsed with %s implementation: %s bytes, success: %s",
        impl_name, #yaml_str, result ~= nil
      ),
      vim.log.levels.DEBUG
    )
    if err then
      vim.notify("[YAML] Error: " .. err, vim.log.levels.DEBUG)
    end
  end
  
  return result, err
end

-- Encode Lua table to YAML string
---@param tbl table Table to encode
---@param opts? table Options for encoding {block_style: boolean}
---@return string|nil yaml_str YAML string or nil on error
---@return string|nil error_message Error message in case of failure
function M.encode(tbl, opts)
  local impl = get_impl()
  local block_style = opts and opts.block_style ~= nil and opts.block_style or true
  
  -- The Rust implementation accepts a boolean for block_style
  -- While the pure Lua implementation expects options table
  local result, err
  if impl == yaml_rust then
    result, err = impl.encode(tbl, block_style)
  else
    result, err = impl.encode(tbl, { block_style = block_style })
  end
  
  -- Log operation if debug is enabled
  local cfg = config.get()
  if cfg.yaml_parser and cfg.yaml_parser.debug then
    local impl_name = (impl == yaml_rust) and "Rust" or "Lua"
    vim.notify(
      string.format("[YAML] Encoded with %s implementation: %s bytes, success: %s",
        impl_name, result and #result or 0, result ~= nil
      ),
      vim.log.levels.DEBUG
    )
    if err then
      vim.notify("[YAML] Error: " .. err, vim.log.levels.DEBUG)
    end
  end
  
  return result, err
end

-- For compatibility with the existing yaml.lua API
M.eval = M.parse
M.dump = function(tbl) print(M.encode(tbl)) end

-- Get information about the active YAML implementation
---@return table info Information about the active implementation
function M.get_implementation_info()
  local impl = get_impl()
  local is_rust = impl == yaml_rust
  
  local info = {
    implementation = is_rust and "Rust" or "Lua",
    available_implementations = {
      rust = yaml_rust and yaml_rust.is_available(),
      lua = true
    }
  }
  
  if is_rust and yaml_rust.version then
    info.version = yaml_rust.version()
  end
  
  return info
end

return M
