-- lua/context-groups/storage.lua
-- Storage functionality extracted from core.lua

local config = require("context-groups.config")
local utils = require("context-groups.utils")

local M = {}

-- Private Storage implementation
---@class Storage
---@field path string Storage file path
---@field data table Data cache
local Storage = {}
Storage.__index = Storage

---Create new storage instance
---@param component string Component identifier
---@return Storage
function Storage.new(component)
  local self = setmetatable({}, Storage)
  self.path = config.get_storage_path(component)
  self.data = {}
  self:load()
  return self
end

---Load data from storage file
---@return boolean success
function Storage:load()
  local content = utils.read_file_content(self.path)
  if not content then
    return false
  end

  local ok, data = pcall(vim.fn.json_decode, content)
  if ok and data then
    self.data = data
    return true
  end

  return false
end

---Save data to storage file
---@return boolean success
function Storage:save()
  local ok, encoded = pcall(vim.fn.json_encode, self.data)
  if not ok then
    return false
  end

  return utils.write_file_content(self.path, encoded)
end

---Get value for key
---@param key string
---@return any value
function Storage:get(key)
  return self.data[key]
end

---Set value for key
---@param key string
---@param value any
---@return boolean success
function Storage:set(key, value)
  self.data[key] = value
  return self:save()
end

---Delete key
---@param key string
---@return boolean success
function Storage:delete(key)
  self.data[key] = nil
  return self:save()
end

---Clear all data
---@return boolean success
function Storage:clear()
  self.data = {}
  return self:save()
end

-- Storage instance cache
---@type table<string, Storage>
local storage_cache = {}

---Get storage instance for a project
---@param root string Project root directory
---@return Storage
function M.get_storage(root)
  if not storage_cache[root] then
    storage_cache[root] = Storage.new("context")
  end
  return storage_cache[root]
end

-- Export the Storage class for direct use if needed
M.Storage = Storage

return M