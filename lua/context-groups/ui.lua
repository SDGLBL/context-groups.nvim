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

  -- LLM Context integration commands
  llm = {
    -- Initialize LLM Context with additional profiles
    init = function()
      -- Use the enhanced initialization module
      local init_llm = require("context-groups.llm.init_llm")
      init_llm.init_llm_context()
    end,

    -- List available profiles
    list_profiles = function()
      local LLMContext = require("context-groups.llm")
      local project = require("context-groups.core")

      local root = project.find_root(vim.fn.expand("%:p"))
      local llm_ctx = LLMContext.new(root)

      if not llm_ctx:is_initialized() then
        vim.notify("LLM Context not initialized. Run :ContextGroupInitLLM first.", vim.log.levels.ERROR)
        return
      end

      local profiles = llm_ctx:get_profiles()
      if #profiles == 0 then
        vim.notify("No profiles found", vim.log.levels.INFO)
        return
      end

      local current = llm_ctx:get_current_profile()
      local lines = { "Available profiles:" }
      for _, profile in ipairs(profiles) do
        table.insert(lines, string.format("%s %s", profile == current and "*" or " ", profile))
      end
      vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    end,

    -- Switch profile
    switch_profile = function(args)
      local LLMContext = require("context-groups.llm")
      local project = require("context-groups.core")

      local root = project.find_root(vim.fn.expand("%:p"))
      local llm_ctx = LLMContext.new(root)

      if not llm_ctx:is_initialized() then
        vim.notify("LLM Context not initialized. Run :ContextGroupInitLLM first.", vim.log.levels.ERROR)
        return
      end

      local profile = args.args
      if profile == "" then
        -- Show profile picker
        picker.show_profile_picker()
      else
        -- Switch to specified profile
        if llm_ctx:switch_profile(profile) then
          vim.notify(string.format("Switched to profile: %s", profile))
        end
      end
    end,

    -- Create profile
    create_profile = function(args)
      local LLMContext = require("context-groups.llm")
      local project = require("context-groups.core")

      local root = project.find_root(vim.fn.expand("%:p"))
      local llm_ctx = LLMContext.new(root)

      if not llm_ctx:is_initialized() then
        vim.notify("LLM Context not initialized. Run :ContextGroupInitLLM first.", vim.log.levels.ERROR)
        return
      end

      local name = args.args
      if name == "" then
        vim.notify("Profile name required", vim.log.levels.ERROR)
        return
      end

      -- Create profile from current context
      if llm_ctx:create_profile_from_context(name, llm_ctx:get_open_buffer_files()) then
        vim.notify(string.format("Created profile '%s' from current context group", name))

        -- Switch to new profile if requested
        if args.bang then
          if llm_ctx:switch_profile(name) then
            vim.notify(string.format("Switched to profile: %s", name))
          end
        end
      else
        vim.notify("Failed to create profile", vim.log.levels.ERROR)
      end
    end,

    -- Sync context group with current profile
    sync = function()
      local LLMContext = require("context-groups.llm")
      local project = require("context-groups.core")

      local root = project.find_root(vim.fn.expand("%:p"))
      local llm_ctx = LLMContext.new(root)

      if not llm_ctx:is_initialized() then
        vim.notify("LLM Context not initialized. Run :ContextGroupInitLLM first.", vim.log.levels.ERROR)
        return
      end

      local current_profile = llm_ctx:get_current_profile()
      if not current_profile then
        vim.notify("No active profile", vim.log.levels.WARN)
        return
      end

      local success = llm_ctx:update_profile_with_buffers(current_profile)
      if success then
        llm_ctx:update_files()
        vim.notify("Context group synced with current profile", vim.log.levels.INFO)
      else
        vim.notify("Failed to sync context group", vim.log.levels.ERROR)
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

  -- code2prompt command
  code2prompt = {
    -- Copy contents of open buffers to clipboard in a formatted way
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

  -- LLM Context commands
  create_command("ContextGroupInitLLM", commands.llm.init, {
    desc = "Initialize LLM Context for the project with additional profiles",
  })

  create_command("ContextGroupListProfiles", commands.llm.list_profiles, {
    desc = "List available LLM Context profiles",
  })

  create_command("ContextGroupSwitchProfile", commands.llm.switch_profile, {
    nargs = "?",
    complete = function()
      local LLMContext = require("context-groups.llm")
      local project = require("context-groups.core")
      local root = project.find_root(vim.fn.expand("%:p"))
      local llm_ctx = LLMContext.new(root)
      return llm_ctx and llm_ctx:get_profiles() or {}
    end,
    desc = "Switch LLM Context profile",
  })

  create_command("ContextGroupCreateProfile", commands.llm.create_profile, {
    nargs = 1,
    bang = true,
    desc = "Create new LLM Context profile from current context group (! to switch)",
  })

  create_command("ContextGroupSync", commands.llm.sync, {
    desc = "Sync context group with current profile",
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

  -- code2prompt command
  create_command("ContextGroupBuffer2Prompt", commands.code2prompt.generate, {
    desc = "Copy contents of open buffers to clipboard in a formatted way",
  })

  -- LSP diagnostics commands
  create_command("ContextGroupLSPDiagnosticsCurrent", commands.lsp_diagnostics.current, {
    desc = "Get LSP diagnostics for current buffer and copy to clipboard",
  })

  create_command("ContextGroupLSPDiagnosticsAll", commands.lsp_diagnostics.all, {
    desc = "Get LSP diagnostics for all open buffers and copy to clipboard",
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

  -- Initialize LLM context
  -- if keymaps.init_llm then
  --   vim.keymap.set("n", keymaps.init_llm, function()
  --     vim.cmd("ContextGroupInitLLM")
  --   end, { desc = "Initialize LLM context" })
  -- end

  -- Select profile
  -- if keymaps.select_profile then
  --   vim.keymap.set("n", keymaps.select_profile, function()
  --     picker.show_profile_picker()
  --   end, { desc = "Select LLM context profile" })
  -- end

  -- Update LLM context
  -- if keymaps.update_llm then
  --   vim.keymap.set("n", keymaps.update_llm, function()
  --     vim.cmd("ContextGroupSync")
  --   end, { desc = "Sync LLM context" })
  -- end

  -- Call code2prompt on all open buffers
  if keymaps.code2prompt then
    vim.keymap.set("n", keymaps.code2prompt, function()
      require("context-groups").call_code2prompt()
    end, { desc = "Copy buffer contents to clipboard in formatted way" })
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

