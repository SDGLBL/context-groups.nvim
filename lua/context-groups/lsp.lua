-- lua/context-groups/lsp.lua
-- Consolidated LSP functionality

local config = require("context-groups.config")
local language_registry = require("context-groups.language")

---@class ImportedFile
---@field path string Complete file path
---@field is_stdlib boolean Whether it's from standard library
---@field is_external boolean Whether it's from external dependencies
---@field name string Display name
---@field parse_error boolean Whether parsing failed
---@field error_message? string Error message if parsing failed
---@field language string Source language
---@field import_path string Original import path

---@class LSPHandler
---@field get_imports fun(bufnr: number): ImportedFile[] Get imported files
---@field is_stdlib fun(path: string): boolean Check if path is from stdlib
---@field is_external fun(path: string): boolean Check if path is from external deps
---@field resolve_import fun(import_path: string, from_file: string): string? Resolve import path to file path

local M = {}

-- Get handler for current buffer
---@param bufnr? number Buffer number (nil for current buffer)
---@return LSPHandler?
local function get_handler(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  return language_registry.get_handler(ft)
end

-- Get all imports for current buffer
---@param bufnr? number Buffer number (nil for current buffer)
---@return ImportedFile[]
function M.get_imported_files(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local handler = get_handler(bufnr)

  if not handler then
    return {}
  end

  local prefs = config.get_import_prefs()
  local imports = handler.get_imports(bufnr)

  -- Filter imports based on preferences
  return vim.tbl_filter(function(import)
    if import.is_stdlib and not prefs.show_stdlib then
      return false
    end
    if import.is_external and not prefs.show_external then
      return false
    end
    -- Check ignore patterns
    for _, pattern in ipairs(prefs.ignore_patterns) do
      if import.path:match(pattern) then
        return false
      end
    end
    return true
  end, imports)
end

-- Resolve import path to file path
---@param import_path string Import path to resolve
---@param from_file string Source file path
---@return string? resolved_path Resolved file path or nil if not found
function M.resolve_import(import_path, from_file)
  local bufnr = vim.fn.bufnr(from_file)
  if bufnr == -1 then
    return nil
  end

  local handler = get_handler(bufnr)
  if not handler then
    return nil
  end

  return handler.resolve_import(import_path, from_file)
end

-- Register handler convenience function
---@param lang string Language identifier
---@param handler LSPHandler Handler implementation
function M.register_handler(lang, handler)
  language_registry.register(lang, handler)
end

-- Setup LSP integration
function M.setup()
  -- Initialize language handlers
  language_registry.init()

  -- Set up LSP handlers for import resolution
  vim.lsp.handlers["textDocument/definition"] = function(err, result, ctx, config_)
    if err then
      return
    end

    local handler = get_handler()
    if not handler then
      return vim.lsp.handlers["textDocument/definition"](err, result, ctx, config_)
    end

    -- Try to handle import resolution first
    local resolved = handler.resolve_import(ctx.params.textDocument.uri, ctx.params.position)
    if resolved then
      return resolved
    end

    -- Fall back to default handler
    return vim.lsp.handlers["textDocument/definition"](err, result, ctx, config_)
  end
end

return M
