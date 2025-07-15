-- lua/context-groups/ui.lua
-- Unified UI module combining functionality from ui/init.lua and ui/commands.lua

local config = require("context-groups.config")
local core = require("context-groups.core")
local picker = require("context-groups.picker")

local M = {}

-- Command groups organized by functionality
local commands = {
  -- Context group commands
  context = {
    -- Add file to context group
    add = function(args)
      if args.args ~= "" then
        local success = core.add_context_file(args.args)
        if success then
          vim.notify(string.format("Added %s to context group", vim.fn.fnamemodify(args.args, ":~:.")))
        else
          vim.notify("Failed to add file to context group", vim.log.levels.ERROR)
        end
      else
        picker.show_file_picker()
      end
    end,

    -- Show context group
    show = function()
      picker.show_context_group()
    end,

    -- Add imports to context group (retained for command use)
    add_imports = function()
      picker.show_imports_picker()
    end,

    -- Remove file from context group
    remove = function(args)
      if args.args ~= "" then
        local success = core.remove_context_file(args.args)
        if success then
          vim.notify(string.format("Removed %s from context group", vim.fn.fnamemodify(args.args, ":~:.")))
        else
          vim.notify("Failed to remove file from context group", vim.log.levels.ERROR)
        end
      else
        picker.show_context_group()
      end
    end,

    -- Clear context group
    clear = function()
      local success = core.clear_context_group()
      if success then
        vim.notify("Cleared context group")
      else
        vim.notify("Failed to clear context group", vim.log.levels.ERROR)
      end
    end,
  },

  -- Preference toggle commands
  prefs = {
    -- Toggle stdlib visibility
    toggle_stdlib = function()
      local prefs = config.get_import_prefs()
      prefs.show_stdlib = not prefs.show_stdlib
      config.update_import_prefs(prefs)
      vim.notify("Standard library imports: " .. (prefs.show_stdlib and "shown" or "hidden"))
    end,

    -- Toggle external deps visibility
    toggle_external = function()
      local prefs = config.get_import_prefs()
      prefs.show_external = not prefs.show_external
      config.update_import_prefs(prefs)
      vim.notify("External dependencies: " .. (prefs.show_external and "shown" or "hidden"))
    end,
  },

  -- Export commands
  export = {
    -- Export context group
    export = function(args)
      local result = core.export.export_contents({
        show_git_changes = args.bang,
      })
      if result then
        vim.notify("Context group exported successfully")
      else
        vim.notify("Failed to export context group", vim.log.levels.ERROR)
      end
    end,

    -- Toggle git changes in export
    toggle_git = function()
      local cfg = config.get()
      cfg.export.show_git_changes = not cfg.export.show_git_changes
      vim.notify("Git changes in export: " .. (cfg.export.show_git_changes and "shown" or "hidden"))
    end,
  },

  -- code2prompt commands
  code2prompt = {
    -- Copy contents of current buffer to clipboard in a formatted way
    generate_current = function()
      require("context-groups").call_code2prompt_current()
    end,

    -- Copy contents of all open buffers to clipboard in a formatted way
    generate = function()
      require("context-groups").call_code2prompt()
    end,
  },

  -- LSP diagnostics commands
  lsp_diagnostics = {
    -- Get LSP diagnostics for current buffer
    current = function()
      require("context-groups").get_lsp_diagnostics_current()
    end,

    -- Get LSP diagnostics for all open buffers
    all = function()
      require("context-groups").get_lsp_diagnostics_all()
    end,

    -- Get current buffer with inline LSP diagnostics
    inline_current = function()
      require("context-groups").get_inline_lsp_diagnostics_current()
    end,

    -- Get all open buffers with inline LSP diagnostics
    inline_all = function()
      require("context-groups").get_inline_lsp_diagnostics_all()
    end,
  },

  -- Git diff commands
  git_diff = {
    -- Get Git diff for current buffer
    current = function()
      require("context-groups").get_git_diff_current()
    end,

    -- Get Git diff for all modified buffers
    all_modified = function()
      require("context-groups").get_git_diff_all_modified()
    end,
  },

  -- Buffer paths command
  buffer_paths = {
    -- Copy relative paths of all open buffers to clipboard
    copy = function()
      require("context-groups").get_buffer_paths()
    end,
  },
}

-- Command factory for creating commands
local function create_command(name, handler, opts)
  opts = opts or {}
  vim.api.nvim_create_user_command(name, handler, opts)
end

-- Register commands
function M.register_commands()
  -- Context group commands
  create_command("ContextGroupAdd", commands.context.add, {
    nargs = "?",
    complete = "file",
    desc = "Add file to context group",
  })

  create_command("ContextGroupShow", commands.context.show, {
    desc = "Show current context group",
  })

  create_command("ContextGroupAddImports", commands.context.add_imports, {
    desc = "Add imported files to context group",
  })

  create_command("ContextGroupRemove", commands.context.remove, {
    nargs = "?",
    complete = function()
      return core.get_context_files()
    end,
    desc = "Remove file from context group",
  })

  create_command("ContextGroupClear", commands.context.clear, {
    desc = "Clear current context group",
  })

  -- Preference commands
  create_command("ContextGroupToggleStdlib", commands.prefs.toggle_stdlib, {
    desc = "Toggle visibility of standard library imports",
  })

  create_command("ContextGroupToggleExternal", commands.prefs.toggle_external, {
    desc = "Toggle visibility of external dependencies",
  })

  -- Export commands
  create_command("ContextGroupExport", commands.export.export, {
    desc = "Export context group contents",
    bang = true,
  })

  create_command("ContextGroupExportToggleGit", commands.export.toggle_git, {
    desc = "Toggle git changes in export",
  })

  -- code2prompt commands
  create_command("ContextGroupBuffer2PromptCurrent", commands.code2prompt.generate_current, {
    desc = "Copy contents of current buffer to clipboard in a formatted way",
  })

  create_command("ContextGroupBuffer2Prompt", commands.code2prompt.generate, {
    desc = "Copy contents of all open buffers to clipboard in a formatted way",
  })

  -- LSP diagnostics commands
  create_command("ContextGroupLSPDiagnosticsCurrent", commands.lsp_diagnostics.current, {
    desc = "Get LSP diagnostics for current buffer and copy to clipboard",
  })

  create_command("ContextGroupLSPDiagnosticsAll", commands.lsp_diagnostics.all, {
    desc = "Get LSP diagnostics for all open buffers and copy to clipboard",
  })

  -- LSP diagnostics inline commands
  create_command("ContextGroupLSPDiagnosticsInlineCurrent", commands.lsp_diagnostics.inline_current, {
    desc = "Get current buffer content with inline LSP diagnostics and copy to clipboard",
  })

  create_command("ContextGroupLSPDiagnosticsInlineAll", commands.lsp_diagnostics.inline_all, {
    desc = "Get all open buffers content with inline LSP diagnostics and copy to clipboard",
  })

  -- Git diff commands
  create_command("ContextGroupGitDiffCurrent", commands.git_diff.current, {
    desc = "Get current buffer with Git diff and copy to clipboard",
  })

  create_command("ContextGroupGitDiffAllModified", commands.git_diff.all_modified, {
    desc = "Get all modified buffers with Git diff and copy to clipboard",
  })

  -- Buffer paths command
  create_command("ContextGroupCopyBufferPaths", commands.buffer_paths.copy, {
    desc = "Copy relative paths of all open buffers to clipboard",
  })
end

-- Set up keymaps
function M.setup_keymaps()
  local keymaps = config.get().keymaps

  -- Add context file
  vim.keymap.set("n", keymaps.add_context, function()
    picker.show_file_picker()
  end, { desc = "Add file to context group" })

  -- Show context group
  vim.keymap.set("n", keymaps.show_context, function()
    picker.show_context_group()
  end, { desc = "Show current context group" })

  -- Call code2prompt on current buffer
  if keymaps.code2prompt_current then
    vim.keymap.set("n", keymaps.code2prompt_current, function()
      require("context-groups").call_code2prompt_current()
    end, { desc = "Copy current buffer content to clipboard in formatted way" })
  end

  -- Call code2prompt on all open buffers
  if keymaps.code2prompt then
    vim.keymap.set("n", keymaps.code2prompt, function()
      require("context-groups").call_code2prompt()
    end, { desc = "Copy all buffer contents to clipboard in formatted way" })
  end

  -- Get LSP diagnostics for current buffer
  if keymaps.lsp_diagnostics_current then
    vim.keymap.set("n", keymaps.lsp_diagnostics_current, function()
      require("context-groups").get_lsp_diagnostics_current()
    end, { desc = "Get LSP diagnostics for current buffer" })
  end

  -- Get LSP diagnostics for all open buffers
  if keymaps.lsp_diagnostics_all then
    vim.keymap.set("n", keymaps.lsp_diagnostics_all, function()
      require("context-groups").get_lsp_diagnostics_all()
    end, { desc = "Get LSP diagnostics for all open buffers" })
  end

  -- Get current buffer with inline LSP diagnostics
  if keymaps.lsp_diagnostics_inline_current then
    vim.keymap.set("n", keymaps.lsp_diagnostics_inline_current, function()
      require("context-groups").get_inline_lsp_diagnostics_current()
    end, { desc = "Get current buffer with inline LSP diagnostics" })
  end

  -- Get all buffers with inline LSP diagnostics
  if keymaps.lsp_diagnostics_inline_all then
    vim.keymap.set("n", keymaps.lsp_diagnostics_inline_all, function()
      require("context-groups").get_inline_lsp_diagnostics_all()
    end, { desc = "Get all buffers with inline LSP diagnostics" })
  end

  -- Get current buffer with Git diff
  if keymaps.git_diff_current then
    vim.keymap.set("n", keymaps.git_diff_current, function()
      require("context-groups").get_git_diff_current()
    end, { desc = "Get current buffer with Git diff" })
  end

  -- Get all modified buffers with Git diff
  if keymaps.git_diff_all_modified then
    vim.keymap.set("n", keymaps.git_diff_all_modified, function()
      require("context-groups").get_git_diff_all_modified()
    end, { desc = "Get all modified buffers with Git diff" })
  end

  -- Copy buffer paths
  if keymaps.buffer_paths then
    vim.keymap.set("n", keymaps.buffer_paths, function()
      require("context-groups").get_buffer_paths()
    end, { desc = "Copy relative paths of all open buffers to clipboard" })
  end
end

-- Initialize UI components
function M.setup()
  -- Register commands
  M.register_commands()

  -- Set up keymaps
  M.setup_keymaps()
end

return M
