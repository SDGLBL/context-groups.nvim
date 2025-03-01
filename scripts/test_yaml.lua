-- Test script for YAML bridge
package.path = package.path .. ";/Users/lijie/project/context-groups.nvim/lua/?.lua;/Users/lijie/project/context-groups.nvim/lua/?/init.lua"

local yaml = require("context-groups.utils.yaml")

-- Print implementation info
local info = yaml.get_implementation_info()
print("YAML Implementation: " .. info.implementation)
if info.version then
  print("Version: " .. info.version)
end

-- Test basic YAML parsing
local test_yaml = [[
profiles:
  code:
    gitignores:
      full_files:
      - .git
      - .gitignore
      - .llm-context/
    settings:
      no_media: true
      with_user_notes: false
    only-include:
      full_files:
      - "**/*"
]]

print("\nParsing YAML...")
local result, err = yaml.parse(test_yaml)
if err then
  print("Error: " .. err)
else
  print("Success! Found " .. #vim.tbl_keys(result) .. " top-level keys")
  
  -- Check some values
  if result.profiles and result.profiles.code then
    print("Found profile 'code'")
    if result.profiles.code.settings then
      print("no_media: " .. tostring(result.profiles.code.settings.no_media))
    end
  end
end

-- Test YAML encoding
print("\nEncoding to YAML...")
local lua_table = {
  profiles = {
    test = {
      gitignores = {
        full_files = {".git", ".gitignore"}
      },
      settings = {
        no_media = true
      }
    }
  }
}

local encoded, err = yaml.encode(lua_table)
if err then
  print("Error: " .. err)
else
  print("Success! Encoded YAML (" .. #encoded .. " bytes)")
  print("\nSample of encoded YAML:")
  print(encoded:sub(1, 200) .. (encoded:len() > 200 and "..." or ""))
end
