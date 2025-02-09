-- lua/context-groups/ui/commands.lua

local config = require("context-groups.config")
local core = require("context-groups.core")
local picker = require("context-groups.ui.picker")

local M = {}

-- LLM Context instance
---@type LLMContext
local llm_ctx = nil

-- Initialize LLM Context
local function ensure_llm_context()
  if not llm_ctx then
    local project = require("context-groups.core.project")
    local LLMContext = require("context-groups.llm_context")
    local root = project.find_root(vim.fn.expand("%:p"))
    llm_ctx = LLMContext.new(root)
  end
  return llm_ctx:is_initialized() or llm_ctx:initialize()
end

-- Create context group profile from current files
local function create_profile_from_current(name, opts)
  opts = opts or {}

  -- Get current context files
  local files = core.get_context_files()
  if #files == 0 then
    vim.notify("No files in current context group", vim.log.levels.WARN)
    return false
  end

  -- Create profile configuration
  return llm_ctx:create_profile_from_context(name, files)
end

-- Update LLM Context from current context group
local function update_llm_files(auto_switch)
  if not ensure_llm_context() then
    return false
  end

  local files = core.get_context_files()
  if #files == 0 then
    vim.notify("No files in current context group", vim.log.levels.WARN)
    return false
  end

  -- Create temporary profile if needed
  local success = true
  if auto_switch then
    local temp_name = "temp_" .. os.time()
    success = create_profile_from_current(temp_name)
    if success then
      success = llm_ctx:switch_profile(temp_name)
    end
  end

  -- Update files
  if success then
    success = llm_ctx:update_files()
  end

  return success
end

-- Setup plugin commands
function M.setup()
  -- Regular context group commands...
  vim.api.nvim_create_user_command("ContextGroupAdd", function(args)
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
  end, {
    nargs = "?",
    complete = "file",
    desc = "Add file to context group",
  })

  -- Show context group
  vim.api.nvim_create_user_command("ContextGroupShow", function()
    picker.show_context_group()
  end, {
    desc = "Show current context group",
  })

  -- Add imports to context group
  vim.api.nvim_create_user_command("ContextGroupAddImports", function()
    picker.show_imports_picker()
  end, {
    desc = "Add imported files to context group",
  })

  -- Remove file from context group
  vim.api.nvim_create_user_command("ContextGroupRemove", function(args)
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
  end, {
    nargs = "?",
    complete = function()
      return core.get_context_files()
    end,
    desc = "Remove file from context group",
  })

  -- Clear context group
  vim.api.nvim_create_user_command("ContextGroupClear", function()
    local success = core.clear_context_group()
    if success then
      vim.notify("Cleared context group")
    else
      vim.notify("Failed to clear context group", vim.log.levels.ERROR)
    end
  end, {
    desc = "Clear current context group",
  })

  -- LLM Context Integration Commands

  -- Initialize LLM Context
  vim.api.nvim_create_user_command("ContextGroupInitLLM", function()
    if ensure_llm_context() then
      vim.notify("LLM Context initialized successfully")
    else
      vim.notify("Failed to initialize LLM Context", vim.log.levels.ERROR)
    end
  end, {
    desc = "Initialize LLM Context for the project",
  })

  -- List available profiles
  vim.api.nvim_create_user_command("ContextGroupListProfiles", function()
    if not ensure_llm_context() then
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
  end, {
    desc = "List available LLM Context profiles",
  })

  -- Switch profile command
  vim.api.nvim_create_user_command("ContextGroupSwitchProfile", function(args)
    if not ensure_llm_context() then
      return
    end

    local profile = args.args
    if profile == "" then
      -- Show profile picker
      require("context-groups.ui.picker").show_profile_picker()
    else
      -- Switch to specified profile
      if llm_ctx:switch_profile(profile) then
        vim.notify(string.format("Switched to profile: %s", profile))
      end
    end
  end, {
    nargs = "?",
    complete = function()
      return llm_ctx and llm_ctx:get_profiles() or {}
    end,
    desc = "Switch LLM Context profile",
  })

  -- Create profile command with more options
  vim.api.nvim_create_user_command("ContextGroupCreateProfile", function(args)
    if not ensure_llm_context() then
      return
    end

    local name = args.args
    if name == "" then
      vim.notify("Profile name required", vim.log.levels.ERROR)
      return
    end

    -- Create profile from current context
    if create_profile_from_current(name) then
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
  end, {
    nargs = 1,
    bang = true,
    desc = "Create new LLM Context profile from current context group (! to switch)",
  })

  -- Update LLM Context files
  vim.api.nvim_create_user_command("ContextGroupUpdateLLM", function(args)
    if update_llm_files(args.bang) then
      vim.notify("Updated LLM Context files")
    else
      vim.notify("Failed to update LLM Context files", vim.log.levels.ERROR)
    end
  end, {
    bang = true,
    desc = "Update LLM Context files (! to create temporary profile)",
  })

  -- Sync context group with current profile
  vim.api.nvim_create_user_command("ContextGroupSync", function()
    if not ensure_llm_context() then
      return
    end

    local current_profile = llm_ctx:get_current_profile()
    if not current_profile then
      vim.notify("No active profile", vim.log.levels.WARN)
      return
    end

    local context_files = core.get_context_files()
    local llm_files = llm_ctx:get_context_files()

    -- Compare files
    local added = {}
    local removed = {}

    for _, file in ipairs(context_files) do
      if not vim.tbl_contains(llm_files, file) then
        table.insert(added, file)
      end
    end

    for _, file in ipairs(llm_files) do
      if not vim.tbl_contains(context_files, file) then
        table.insert(removed, file)
      end
    end

    -- Show differences
    if #added > 0 or #removed > 0 then
      local lines = {}
      if #added > 0 then
        table.insert(lines, "Files to add:")
        for _, file in ipairs(added) do
          table.insert(lines, "  + " .. file)
        end
      end
      if #removed > 0 then
        table.insert(lines, "Files to remove:")
        for _, file in ipairs(removed) do
          table.insert(lines, "  - " .. file)
        end
      end
      vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    else
      vim.notify("Context group is in sync with current profile", vim.log.levels.INFO)
    end
  end, {
    desc = "Show differences between context group and current profile",
  })

  -- Toggle preference commands
  vim.api.nvim_create_user_command("ContextGroupToggleStdlib", function()
    local prefs = config.get_import_prefs()
    prefs.show_stdlib = not prefs.show_stdlib
    config.update_import_prefs(prefs)
    vim.notify("Standard library imports: " .. (prefs.show_stdlib and "shown" or "hidden"))
  end, {
    desc = "Toggle visibility of standard library imports",
  })

  vim.api.nvim_create_user_command("ContextGroupToggleExternal", function()
    local prefs = config.get_import_prefs()
    prefs.show_external = not prefs.show_external
    config.update_import_prefs(prefs)
    vim.notify("External dependencies: " .. (prefs.show_external and "shown" or "hidden"))
  end, {
    desc = "Toggle visibility of external dependencies",
  })

  -- Export commands
  vim.api.nvim_create_user_command("ContextGroupExport", function(args)
    local export = require("context-groups.core.export")
    local success = export.export_contents({
      show_git_changes = args.bang,
    })
    if success then
      vim.notify("Context group exported successfully")
    else
      vim.notify("Failed to export context group", vim.log.levels.ERROR)
    end
  end, {
    desc = "Export context group contents",
    bang = true,
  })

  vim.api.nvim_create_user_command("ContextGroupExportToggleGit", function()
    local cfg = config.get()
    cfg.export.show_git_changes = not cfg.export.show_git_changes
    vim.notify("Git changes in export: " .. (cfg.export.show_git_changes and "shown" or "hidden"))
  end, {
    desc = "Toggle git changes in export",
  })
end

return M
