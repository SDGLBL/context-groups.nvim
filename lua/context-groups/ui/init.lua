-- lua/context-groups/ui/init.lua

local commands = require("context-groups.ui.commands")
local config = require("context-groups.config")
local picker = require("context-groups.ui.picker")

local M = {}

-- Initialize UI components
function M.setup()
  -- Set up commands
  commands.setup()

  -- Set up keymaps
  local keymaps = config.get().keymaps

  -- Add context file
  vim.keymap.set("n", keymaps.add_context, function()
    picker.show_file_picker()
  end, { desc = "Add file to context group" })

  -- Show context group
  vim.keymap.set("n", keymaps.show_context, function()
    picker.show_context_group()
  end, { desc = "Show current context group" })

  -- Add imports to context
  if keymaps.add_imports then
    vim.keymap.set("n", keymaps.add_imports, function()
      picker.show_imports_picker()
    end, { desc = "Add imports to context group" })
  end

  -- Update LLM context
  if keymaps.update_llm then
    vim.keymap.set("n", keymaps.update_llm, function()
      vim.cmd("ContextGroupSync")
    end, { desc = "Sync LLM context" })
  end
end

return M
