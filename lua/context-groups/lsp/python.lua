-- lua/context-groups/lsp/python.lua

local config = require("context-groups.config")

local M = {}

-- Cache for Python path information
local path_cache = {
  stdlib = nil,
  site_packages = nil,
  venv = nil,
}

-- Initialize Python paths
local function init_paths()
  if not path_cache.stdlib then
    path_cache.stdlib = vim.fn.system("python -c 'import sys; print(sys.prefix)'"):gsub("\n", "")
  end

  if not path_cache.site_packages then
    path_cache.site_packages = vim.fn.system("python -c 'import site; print(site.getsitepackages()[0])'"):gsub("\n", "")
  end

  -- Try to detect virtual environment
  local venv = vim.env.VIRTUAL_ENV
  if venv then
    path_cache.venv = venv
  end
end

-- Parse Python imports from buffer
---@param bufnr number Buffer number
---@return table[] imports List of import information
local function parse_imports(bufnr)
  local imports = {}
  local content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local function add_import(import_path, line, col)
    table.insert(imports, {
      path = import_path,
      line = line,
      character = col,
    })
  end

  for lnum, line in ipairs(content) do
    -- Match 'import module' and 'from module import name'
    local import_match = line:match("^%s*import%s+([%w%.]+)")
    local from_match = line:match("^%s*from%s+([%w%.]+)%s+import")

    if import_match then
      add_import(import_match, lnum - 1, line:find(import_match) - 1)
    elseif from_match then
      add_import(from_match, lnum - 1, line:find(from_match) - 1)
    end
  end

  return imports
end

-- Resolve Python module to file path
---@param module_path string Module import path
---@param from_file string Source file path
---@return string? file_path Resolved file path or nil
local function resolve_module(module_path, from_file)
  local lang_config = config.get_language_config("python")

  -- Try using Jedi LSP first
  if lang_config.resolve_strategy == "jedi" then
    local params = {
      textDocument = { uri = vim.uri_from_fname(from_file) },
      position = { line = 0, character = 0 },
      context = { triggerKind = 1 },
    }

    local clients = vim.lsp.get_clients({ bufnr = vim.fn.bufnr(from_file) })
    for _, client in pairs(clients) do
      if client.name == "jedi_language_server" then
        local result = client.request_sync("textDocument/definition", params, 1000, vim.fn.bufnr(from_file))
        if result and result.result and result.result[1] then
          return vim.uri_to_fname(result.result[1].uri)
        end
      end
    end
  end

  -- Fallback to manual resolution
  local module_parts = vim.split(module_path, ".", { plain = true, trimempty = false })
  local module_file = table.concat(module_parts, "/") .. ".py"

  -- Search paths
  local search_paths = {
    vim.fn.fnamemodify(from_file, ":h"),
    path_cache.stdlib and path_cache.stdlib .. "/lib/python3*/site-packages" or nil,
    path_cache.site_packages,
    path_cache.venv and path_cache.venv .. "/lib/python3*/site-packages" or nil,
  }

  for _, base_path in ipairs(search_paths) do
    if base_path then
      local full_path = base_path .. "/" .. module_file
      if vim.fn.filereadable(full_path) == 1 then
        return full_path
      end
      -- Also check for __init__.py
      local init_path = base_path .. "/" .. module_file:gsub("%.py$", "/__init__.py")
      if vim.fn.filereadable(init_path) == 1 then
        return init_path
      end
    end
  end

  return nil
end

-- Check if path is in Python standard library
---@param path string File path
---@return boolean
local function is_stdlib(path)
  if not path or path == "" then
    return false
  end

  return vim.startswith(path, path_cache.stdlib)
end

-- Check if path is in external dependencies
---@param path string File path
---@return boolean
local function is_external(path)
  return vim.startswith(path, path_cache.site_packages)
    or (path_cache.venv ~= nil and vim.startswith(path, path_cache.venv))
end

-- Get imported files for Python buffer
---@param bufnr number Buffer number
---@return ImportedFile[]
local function get_imports(bufnr)
  local imports = parse_imports(bufnr)
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local results = {}

  for _, import in ipairs(imports) do
    local resolved_path = resolve_module(import.path, file_path)

    if resolved_path then
      table.insert(results, {
        path = resolved_path,
        is_stdlib = is_stdlib(resolved_path),
        is_external = is_external(resolved_path),
        name = import.path,
        parse_error = false,
        language = "python",
        import_path = import.path,
      })
    else
      table.insert(results, {
        path = "",
        is_stdlib = false,
        is_external = false,
        name = import.path,
        parse_error = true,
        error_message = "Could not resolve import path",
        language = "python",
        import_path = import.path,
      })
    end
  end

  return results
end

-- Register Python LSP handler
function M.setup()
  -- Initialize paths when setting up
  init_paths()

  require("context-groups.lsp").register_handler("python", {
    get_imports = get_imports,
    is_stdlib = is_stdlib,
    is_external = is_external,
    resolve_import = resolve_module,
  })
end

return M
