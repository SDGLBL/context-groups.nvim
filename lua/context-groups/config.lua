---@class ContextGroupsKeymaps
---@field add_context string Keymap to add context file
---@field show_context string Keymap to show context group
---@field init_llm? string Keymap to initialize LLM context
---@field select_profile? string Keymap to select LLM context profile
---@field update_llm? string Keymap to update LLM context
---@field code2prompt? string Keymap to copy buffer contents to clipboard in a formatted way
---@field lsp_diagnostics_current? string Keymap to get LSP diagnostics for current buffer
---@field lsp_diagnostics_all? string Keymap to get LSP diagnostics for all open buffers
---@field lsp_diagnostics_inline_current? string Keymap to get current buffer with inline LSP diagnostics
---@field lsp_diagnostics_inline_all? string Keymap to get all buffers with inline LSP diagnostics
---@field buffer_paths? string Keymap to copy relative paths of all open buffers to clipboard

---@class ImportPreferences
---@field show_stdlib boolean Show standard library imports
---@field show_external boolean Show external dependencies
---@field ignore_patterns string[] Patterns to ignore when importing

---@class YamlParserConfig
---@field debug boolean Enable debug mode for YAML parser
---@field block_style boolean Use block style for YAML output

---@class ContextGroupsConfig
---@field keymaps ContextGroupsKeymaps Key mappings configuration
---@field storage_path? string Path to store plugin data
---@field import_prefs ImportPreferences Import preferences
---@field project_markers string[] Markers to identify project root
---@field max_preview_lines? number Maximum lines to show in preview
---@field telescope_theme? table Custom telescope theme
---@field on_context_change? function Called when context group changes
---@field language_config table<string, table> Language specific configurations
---@field export table<string, any> Export configuration
---@field yaml_parser YamlParserConfig YAML parser configuration

local M = {}

-- Default configuration
local DEFAULT_CONFIG = {
  yaml_parser = {
    debug = false,
    block_style = true,
  },
  keymaps = {
    add_context = "<leader>ca",
    show_context = "<leader>cS",
    init_llm = "<leader>ci",
    select_profile = "<leader>cs",
    update_llm = "<leader>cr",
    code2prompt = "<leader>cy",
    lsp_diagnostics_current = "<leader>cl",
    lsp_diagnostics_all = "<leader>cL",
    lsp_diagnostics_inline_current = "<leader>cI",
    lsp_diagnostics_inline_all = "<leader>cA",
    buffer_paths = "<leader>cp",
  },
  storage_path = vim.fn.stdpath("data") .. "/context-groups",
  import_prefs = {
    show_stdlib = false,
    show_external = false,
    ignore_patterns = {},
  },
  project_markers = {
    ".git",
    ".svn",
    "package.json",
    "Cargo.toml",
    "go.mod",
    "requirements.txt",
  },
  max_preview_lines = 500,
  telescope_theme = nil,
  on_context_change = nil,
  language_config = {
    go = {
      resolve_strategy = "gopls",
      stdlib_path = vim.fn.systemlist("go env GOROOT")[1],
      external_path = vim.fn.systemlist("go env GOPATH")[1],
    },
    python = {
      resolve_strategy = "jedi",
      venv_detection = true,
      follow_imports = true,
    },
  },
  export = {
    max_tree_depth = 4, -- 项目树的最大深度
    show_git_changes = true, -- 是否显示git变更
    exclude_patterns = { -- 要排除的文件模式
      "__pycache__",
      "node_modules",
      ".git",
      ".idea",
      ".vscode",
      "build",
      "dist",
      ".pytest_cache",
      ".mypy_cache",
      ".tox",
      "venv",
      "env",
      "data",
    },
  },
}

-- Active configuration
---@type ContextGroupsConfig
local config = vim.deepcopy(DEFAULT_CONFIG)

---Update configuration with user settings
---@param user_config ContextGroupsConfig User configuration
function M.setup(user_config)
  -- Deep merge user config with defaults
  config = vim.tbl_deep_extend("force", DEFAULT_CONFIG, user_config or {})

  -- Ensure storage path exists
  vim.fn.mkdir(config.storage_path, "p")
end

---Get current configuration
---@return ContextGroupsConfig
function M.get()
  return config
end

---Get configuration for specific language
---@param lang string Language identifier
---@return table Language specific configuration
function M.get_language_config(lang)
  return config.language_config[lang] or {}
end

---Get import preferences
---@return ImportPreferences
function M.get_import_prefs()
  return config.import_prefs
end

---Update import preferences
---@param prefs ImportPreferences
function M.update_import_prefs(prefs)
  config.import_prefs = vim.tbl_deep_extend("force", config.import_prefs, prefs)
  -- 触发回调
  if config.on_context_change then
    config.on_context_change()
  end
end

---Get storage path for specific component
---@param component string Component identifier (e.g., "context", "imports")
---@return string Full path for component storage
function M.get_storage_path(component)
  return config.storage_path .. "/" .. component .. ".json"
end

return M
