---@class ContextGroupsKeymaps
---@field add_context string Keymap to add context file
---@field show_context string Keymap to show context group
---@field code2prompt_current? string Keymap to copy current buffer contents to clipboard in a formatted way
---@field code2prompt? string Keymap to copy all buffer contents to clipboard in a formatted way
---@field lsp_diagnostics_current? string Keymap to get LSP diagnostics for current buffer
---@field lsp_diagnostics_all? string Keymap to get LSP diagnostics for all open buffers
---@field lsp_diagnostics_inline_current? string Keymap to get current buffer with inline LSP diagnostics
---@field lsp_diagnostics_inline_all? string Keymap to get all buffers with inline LSP diagnostics
---@field git_diff_current? string Keymap to get current buffer with Git diff
---@field git_diff_all_modified? string Keymap to get all modified buffers with Git diff
---@field buffer_paths? string Keymap to copy relative paths of all open buffers to clipboard

---@class ImportPreferences
---@field show_stdlib boolean Show standard library imports
---@field show_external boolean Show external dependencies
---@field ignore_patterns string[] Patterns to ignore when importing

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

local M = {}

-- Default configuration
local DEFAULT_CONFIG = {
  keymaps = {
    add_context = "<leader>ca",
    show_context = "<leader>cs",
    code2prompt_current = "<leader>cy",
    code2prompt = "<leader>cY",
    lsp_diagnostics_current = "<leader>cl",
    lsp_diagnostics_all = "<leader>cL",
    lsp_diagnostics_inline_current = "<leader>cI",
    lsp_diagnostics_inline_all = "<leader>cA",
    git_diff_current = "<leader>cg",
    git_diff_all_modified = "<leader>cG",
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
    max_tree_depth = 4, -- Maximum depth of project tree
    show_git_changes = true, -- Show git changes
    exclude_patterns = { -- File patterns to exclude
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
  -- Trigger callback
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
