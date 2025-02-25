-- lua/context-groups/language/go.lua
-- Go language handler implementation

local config = require("context-groups.config")

local M = {}

-- Test interface
M.test = {}

-- Go path cache
local path_cache = {
  -- GOROOT path (standard library location)
  stdlib = nil,
  -- GOPATH path
  gopath = nil,
  -- go.mod cache
  mod_cache = {},
  -- package cache
  pkg_cache = {},
}

-- Initialize Go environment paths
local function init_paths()
  if not path_cache.stdlib then
    -- Get GOROOT
    local goroot = vim.fn.systemlist("go env GOROOT")
    if goroot and goroot[1] then
      path_cache.stdlib = goroot[1]
    end
  end

  if not path_cache.gopath then
    -- Get GOPATH
    local gopath = vim.fn.systemlist("go env GOPATH")
    if gopath and gopath[1] then
      path_cache.gopath = gopath[1]
    end
  end
end

-- Add cache clearing test function
M.test.clear_cache = function()
  path_cache.mod_cache = {}
end

-- Parse go.mod file
---@param file_path string mod file path
---@return table? mod_info Module information
local function parse_go_mod(file_path)
  -- Check cache
  if path_cache.mod_cache[file_path] then
    return path_cache.mod_cache[file_path]
  end

  -- Read file content
  local content = vim.fn.readfile(file_path)
  if not content or #content == 0 then
    return {
      module = nil,
      requires = {},
      replaces = {},
    }
  end

  -- Storage for parsing results
  local mod_info = {
    module = nil,
    requires = {},
    replaces = {},
  }

  -- Current parsing state
  local state = {
    in_require_block = false,
    in_replace_block = false,
  }

  -- Preprocess: remove all comments (including inline and multi-line)
  local function remove_comments(line)
    -- Remove // comments
    line = line:gsub("//.*$", "")
    -- Remove /* */ comments (single line case)
    line = line:gsub("/%*.-%*/", "")
    -- Clean whitespace
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    return line
  end

  local function parse_module_line(line)
    local module = line:match("^module%s+(.+)$")
    if module then
      return module:gsub("[\"']", "")
    end
    return nil
  end

  local function parse_require_line(line)
    -- Match require x.y.z v1.2.3 format
    local mod, ver = line:match("^([^%s]+)%s+[\"']?([^%s\"']+)[\"']?$")
    if mod and ver then
      return mod:gsub("[\"']", ""), ver
    end
    return nil, nil
  end

  local function parse_replace_line(line)
    -- Match x.y.z => a.b.c v1.2.3 format
    local old, new = line:match("^([^%s]+)%s*=>%s*([^%s].+)$")
    if old and new then
      return old:gsub("[\"']", ""), new:gsub("[\"']", "")
    end
    return nil, nil
  end

  for _, raw_line in ipairs(content) do
    local line = remove_comments(raw_line)
    if line ~= "" then
      -- Handle block start and end
      if line == "require (" then
        state.in_require_block = true
      elseif line == "replace (" then
        state.in_replace_block = true
      elseif line == ")" then
        state.in_require_block = false
        state.in_replace_block = false
      -- Handle module declaration
      elseif line:match("^module%s+") then
        mod_info.module = parse_module_line(line)
      -- Handle single-line require
      elseif line:match("^require%s+") and not line:match("^require%s+%(") then
        local mod, ver = parse_require_line(line:gsub("^require%s+", ""))
        if mod and ver then
          mod_info.requires[mod] = ver
        end
      -- Handle block require
      elseif state.in_require_block then
        local mod, ver = parse_require_line(line)
        if mod and ver then
          mod_info.requires[mod] = ver
        end
      -- Handle single-line replace
      elseif line:match("^replace%s+") then
        local old, new = parse_replace_line(line:gsub("^replace%s+", ""))
        if old and new then
          mod_info.replaces[old] = new
        end
      -- Handle block replace
      elseif state.in_replace_block then
        local old, new = parse_replace_line(line)
        if old and new then
          mod_info.replaces[old] = new
        end
      end
    end
  end

  -- Cache result
  path_cache.mod_cache[file_path] = mod_info
  return mod_info
end

-- Export for testing
M.test.parse_go_mod = parse_go_mod

-- Find nearest go.mod file
---@param start_path string Start search path
---@return string? mod_path go.mod path
local function find_nearest_go_mod(start_path)
  local current = start_path
  while current ~= "/" do
    local mod_path = current .. "/go.mod"
    if vim.fn.filereadable(mod_path) == 1 then
      return mod_path
    end
    current = vim.fn.fnamemodify(current, ":h")
  end
  return nil
end

-- Parse import statements
---@param bufnr number Buffer number
---@return table[] imports Import information list
function M.test.parse_imports(bufnr)
  local imports = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local in_import_block = false
  for lnum, line in ipairs(lines) do
    -- Remove comments
    line = line:gsub("//.*$", "")
    line = line:gsub("/%*.-%*/", "")

    -- Match imports
    if not in_import_block then
      -- Single-line import
      local single_import = line:match('^%s*import%s+"([^"]+)"')
      if single_import then
        table.insert(imports, {
          package = single_import,
          line = lnum - 1,
          character = line:find('"'),
        })
      end

      -- Import block start
      if line:match("^%s*import%s+%(") then
        in_import_block = true
      end
    else
      -- Import block end
      if line:match("^%s*%)") then
        in_import_block = false
      else
        -- Block import
        local name, path = line:match('^%s*([%w_]+)%s+"([^"]+)"')
        if path then
          -- Named import
          table.insert(imports, {
            package = path,
            alias = name ~= "_" and name or nil,
            line = lnum - 1,
            character = line:find('"'),
          })
        else
          -- Regular import
          path = line:match('^%s*"([^"]+)"')
          if path then
            table.insert(imports, {
              package = path,
              line = lnum - 1,
              character = line:find('"'),
            })
          end
        end
      end
    end
  end

  return imports
end

-- Check if package is from standard library
---@param pkg_path string Package path
---@return boolean
local function is_stdlib(pkg_path)
  if not path_cache.stdlib or pkg_path:match("^[%w%.%-_]+/") then
    return false
  end

  local pkg_name = pkg_path:match("^([%w%.%-_]+)$")
  if not pkg_name then
    return false
  end

  -- Check standard library path
  local std_path = path_cache.stdlib .. "/src/" .. pkg_name
  return vim.fn.isdirectory(std_path) == 1
end

-- Check if package is from external dependency
---@param pkg_path string Package path
---@param mod_info table go.mod information
---@return boolean
local function is_external(pkg_path, mod_info)
  if not mod_info then
    return false
  end

  -- Check if matches any external dependency
  for dep_path, _ in pairs(mod_info.requires) do
    if vim.startswith(pkg_path, dep_path) then
      return true
    end
  end

  return false
end

-- Resolve package to file path
---@param pkg_path string Package path
---@param from_file string Source file path
---@return string? resolved_path Resolved file path
local function resolve_package(pkg_path, from_file)
  -- If standard library
  if is_stdlib(pkg_path) then
    local std_path = path_cache.stdlib .. "/src/" .. pkg_path
    if vim.fn.isdirectory(std_path) == 1 then
      -- Return main file in package
      local main_file = std_path .. "/" .. vim.fn.fnamemodify(pkg_path, ":t") .. ".go"
      if vim.fn.filereadable(main_file) == 1 then
        return main_file
      end
    end
    return nil
  end

  -- Find project's go.mod
  local mod_path = find_nearest_go_mod(from_file)
  if not mod_path then
    return nil
  end

  local mod_info = parse_go_mod(mod_path)
  if not mod_info then
    return nil
  end

  -- If internal package
  if vim.startswith(pkg_path, mod_info.module) then
    local rel_path = pkg_path:sub(#mod_info.module + 2)
    local pkg_dir = vim.fn.fnamemodify(mod_path, ":h") .. "/" .. rel_path
    if vim.fn.isdirectory(pkg_dir) == 1 then
      -- Return main file in package
      local main_file = pkg_dir .. "/" .. vim.fn.fnamemodify(rel_path, ":t") .. ".go"
      if vim.fn.filereadable(main_file) == 1 then
        return main_file
      end
    end
    return nil
  end

  -- If external dependency
  local gopath = path_cache.gopath
  if gopath then
    -- Check GOPATH
    local pkg_dir = gopath .. "/pkg/mod/" .. pkg_path
    if vim.fn.isdirectory(pkg_dir) == 1 then
      -- Return main file in package
      local main_file = pkg_dir .. "/" .. vim.fn.fnamemodify(pkg_path, ":t") .. ".go"
      if vim.fn.filereadable(main_file) == 1 then
        return main_file
      end
    end
  end

  return nil
end

-- Get imported files
---@param bufnr number Buffer number
---@return ImportedFile[]
local function get_imports(bufnr)
  local imports = M.test.parse_imports(bufnr)
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local results = {}

  -- Get go.mod information
  local mod_path = find_nearest_go_mod(file_path)
  local mod_info = mod_path and parse_go_mod(mod_path)

  for _, import in ipairs(imports) do
    local pkg_path = import.package
    local resolved_path = resolve_package(pkg_path, file_path)

    if resolved_path then
      table.insert(results, {
        path = resolved_path,
        is_stdlib = is_stdlib(pkg_path),
        is_external = is_external(pkg_path, mod_info),
        name = pkg_path,
        parse_error = false,
        language = "go",
        import_path = pkg_path,
      })
    else
      table.insert(results, {
        path = "",
        is_stdlib = false,
        is_external = false,
        name = pkg_path,
        parse_error = true,
        error_message = "Could not resolve import path: " .. pkg_path,
        language = "go",
        import_path = pkg_path,
      })
    end
  end

  return results
end

M.test.get_imports = get_imports

-- Setup handler
function M.setup()
  -- Initialize paths
  init_paths()

  -- Register handler
  require("context-groups.lsp").register_handler("go", {
    get_imports = get_imports,
    is_stdlib = is_stdlib,
    is_external = function(path)
      return is_external(path, {})
    end,
    resolve_import = resolve_package,
  })
end

return M
