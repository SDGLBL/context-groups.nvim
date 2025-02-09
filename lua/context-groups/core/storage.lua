-- lua/context-groups/core/storage.lua

local config = require("context-groups.config")

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
  local file = io.open(self.path, "r")
  if not file then
    return false
  end

  local content = file:read("*all")
  file:close()

  if content and content ~= "" then
    local ok, data = pcall(vim.fn.json_decode, content)
    if ok then
      self.data = data
      return true
    end
  end

  return false
end

---Save data to storage file
---@return boolean success
function Storage:save()
  local file = io.open(self.path, "w")
  if not file then
    return false
  end

  local ok, encoded = pcall(vim.fn.json_encode, self.data)
  if not ok then
    file:close()
    return false
  end

  file:write(encoded)
  file:close()
  return true
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

return Storage
