-- lua/context-groups/language/init.lua
-- Central registry for language handlers

---@class LanguageRegistry
local M = {}

-- Handler registry
---@type table<string, LSPHandler>
local handlers = {}

---Register a language handler
---@param lang string Language identifier
---@param handler LSPHandler Handler implementation
function M.register(lang, handler)
  handlers[lang] = handler
end

---Get handler for a language
---@param lang string Language identifier
---@return LSPHandler? handler
function M.get_handler(lang)
  return handlers[lang]
end

---Get all registered languages
---@return string[] languages
function M.get_languages()
  local languages = {}
  for lang, _ in pairs(handlers) do
    table.insert(languages, lang)
  end
  table.sort(languages)
  return languages
end

---Initialize language handlers
function M.init()
  -- Load language handlers
  require("context-groups.language.go").setup()
  require("context-groups.language.python").setup()
  
  -- Additional languages can be added here in the future
end

return M
