-- lua/context-groups/utils/toml.lua

local TOML = {
  version = 0.40,
  strict = true,
}

local function escapeStr(str, multiline)
  if multiline then
    return str
  end
  str = str:gsub("\\", "\\\\")
  str = str:gsub("\b", "\\b")
  str = str:gsub("\t", "\\t")
  str = str:gsub("\f", "\\f")
  str = str:gsub("\r", "\\r")
  str = str:gsub('"', '\\"')
  str = str:gsub("\n", "\\n")
  return str
end

local function encodeKey(key)
  if key:match("^[A-Za-z0-9_-]+$") then
    return key
  end
  return '"' .. escapeStr(key) .. '"'
end

local function encodeValue(val, indent)
  indent = indent or ""
  local t = type(val)
  if t == "string" then
    if val:find("\n") then
      -- Use literal multi-line string for better readability
      return '"""\n' .. val:gsub('\n$', '') .. '\n"""'
    end
    return '"' .. escapeStr(val) .. '"'
  elseif t == "number" or t == "boolean" then
    return tostring(val)
  elseif t == "table" then
    -- Check if it's an array
    local isArray = true
    local maxIndex = 0
    for k, _ in pairs(val) do
      if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
        isArray = false
        break
      end
      maxIndex = math.max(maxIndex, k)
    end

    if isArray and maxIndex > 0 then
      -- Process array
      local items = {}
      for i = 1, maxIndex do
        local v = val[i]
        if v ~= nil then
          table.insert(items, encodeValue(v, indent .. "  "))
        end
      end
      return "[\n" .. indent .. items[1] .. (items[2] and ",\n" .. indent .. table.concat(items, ",\n" .. indent, 2) or "") .. ",\n" .. indent .. "]"
    else
      -- Process inline table
      local items = {}
      local keys = {}
      for k in pairs(val) do
        table.insert(keys, k)
      end
      table.sort(keys)
      
      local needsFormatting = false
      for _, k in ipairs(keys) do
        local v = val[k]
        if type(v) == "table" and next(v) and (not isArray or #v > 0) then
          needsFormatting = true
          break
        end
      end

      if needsFormatting then
        return nil -- Signal that this table needs full formatting
      end

      if #keys == 0 then
        return "{}"
      end

      for _, k in ipairs(keys) do
        local v = val[k]
        if v ~= nil then
          table.insert(items, encodeKey(k) .. " = " .. encodeValue(v, indent .. "  "))
        end
      end
      
      return "{ " .. table.concat(items, ", ") .. " }"
    end
  end
  error("Cannot encode type: " .. t)
end

local function encode(tbl)
  local lines = {}
  local tables = {}

  -- Collect and sort table paths
  local function collectTables(t, prefix)
    local keys = {}
    for k in pairs(t) do
      table.insert(keys, k)
    end
    table.sort(keys)

    for _, k in ipairs(keys) do
      local v = t[k]
      if type(v) == "table" and next(v) then
        local value = encodeValue(v)
        if value == nil then -- Table needs full formatting
          local path = prefix and (prefix .. "." .. k) or k
          table.insert(tables, path)
          collectTables(v, path)
        end
      end
    end
  end

  -- Process values at current level
  local function processValues(t)
    local keys = {}
    for k in pairs(t) do
      table.insert(keys, k)
    end
    table.sort(keys)

    for _, k in ipairs(keys) do
      local v = t[k]
      local value = encodeValue(v)
      if value ~= nil then -- Directly encodable value
        table.insert(lines, encodeKey(k) .. " = " .. value)
      end
    end
  end

  -- First pass: collect tables
  collectTables(tbl)

  -- Second pass: process root values
  processValues(tbl)

  -- Third pass: process nested tables
  for _, path in ipairs(tables) do
    -- Find the target table
    local target = tbl
    local parts = {}
    for part in path:gmatch("[^%.]+") do
      table.insert(parts, part)
    end
    for _, part in ipairs(parts) do
      target = target[part]
    end

    -- Add table header and values
    if next(target) then
      if #lines > 0 then
        table.insert(lines, "")
      end
      table.insert(lines, "[" .. path .. "]")
      processValues(target)
    end
  end

  return table.concat(lines, "\n")
end

-- Parse functions
local function parse(toml, options)
  options = options or {}
  local strict = (options.strict ~= nil and options.strict or TOML.strict)

  local ws = "[\009\032]"
  local nl = "[\10\13\10]"
  local buffer = ""
  local cursor = 1
  local out = {}
  local obj = out

  local function char(n)
    n = n or 0
    return toml:sub(cursor + n, cursor + n)
  end

  local function step(n)
    n = n or 1
    cursor = cursor + n
  end

  local function skipWhitespace()
    while char():match(ws) do
      step()
    end
  end

  local function trim(str)
    return str:gsub("^%s*(.-)%s*$", "%1")
  end

  local function bounds()
    return cursor <= toml:len()
  end

  local function err(message)
    local line = 1
    local c = 0
    for l in toml:gmatch("(.-)" .. nl) do
      c = c + l:len()
      if c >= cursor then
        break
      end
      line = line + 1
    end
    error("TOML: " .. message .. (message:match("Cannot redefine table") and "" or " on line " .. line .. "."), 4)
  end

  -- Forward declarations for mutual recursion
  local parseValue

  local function parseString()
    local quoteType = char()
    local multiline = (char(1) == char(2) and char(1) == char())
    local str = ""

    step(multiline and 3 or 1)

    while bounds() do
      if multiline and char():match(nl) and str == "" then
        step()
      end

      if char() == quoteType then
        if multiline then
          if char(1) == char(2) and char(1) == quoteType then
            step(3)
            break
          end
        else
          step()
          break
        end
      end

      if char():match(nl) and not multiline then
        err("Single-line string cannot contain line break")
      end

      if quoteType == '"' and char() == "\\" then
        step()
        local escape = {
          b = "\b",
          t = "\t",
          n = "\n",
          f = "\f",
          r = "\r",
          ['"'] = '"',
          ["\\"] = "\\",
        }
        if escape[char()] then
          str = str .. escape[char()]
        else
          err("Invalid escape sequence")
        end
      else
        str = str .. char()
      end
      step()
    end

    return str
  end

  local function parseNumber()
    local num = ""
    while bounds() and char():match("[%+%-%.eE_0-9]") do
      if char() ~= "_" then
        num = num .. char()
      end
      step()
    end
    return tonumber(num)
  end

  local function parseArray()
    local array = {}
    step() -- skip [
    skipWhitespace()

    while bounds() do
      if char() == "]" then
        step()
        break
      elseif char():match(nl) or char() == ","