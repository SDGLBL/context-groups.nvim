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

-- Setup plugin commands
function M.setup()
  -- Add file to context group
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

  -- Toggle import preferences
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

  -- 添加导出命令
  vim.api.nvim_create_user_command("ContextGroupExport", function(args)
    local export = require("context-groups.core.export")
    local success = export.export_contents({
      show_git_changes = args.bang, -- 使用 ! 来控制是否显示 git 变更
    })
    if success then
      vim.notify("Context group exported successfully")
    else
      vim.notify("Failed to export context group", vim.log.levels.ERROR)
    end
  end, {
    desc = "Export context group contents",
    bang = true, -- 允许使用 ! 标记
  })

  -- 添加导出偏好设置切换命令
  vim.api.nvim_create_user_command("ContextGroupExportToggleGit", function()
    local cfg = config.get()
    cfg.export.show_git_changes = not cfg.export.show_git_changes
    vim.notify("Git changes in export: " .. (cfg.export.show_git_changes and "shown" or "hidden"))
  end, {
    desc = "Toggle git changes in export",
  })
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

  -- Switch LLM Context profile
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

  -- Create new profile from current context group
  vim.api.nvim_create_user_command("ContextGroupCreateProfile", function(args)
    if not ensure_llm_context() then
      return
    end

    local name = args.args
    if name == "" then
      vim.notify("Profile name required", vim.log.levels.ERROR)
      return
    end

    -- Get current context files
    local files = core.get_context_files()

    -- Create profile configuration
    local success = llm_ctx:create_profile(name, {
      only_include = {
        full_files = files,
      },
      settings = {
        no_media = true,
        with_user_notes = true,
      },
    })

    if success then
      vim.notify(string.format("Created profile: %s", name))
    else
      vim.notify("Failed to create profile", vim.log.levels.ERROR)
    end
  end, {
    nargs = 1,
    desc = "Create new LLM Context profile from current context group",
  })

  -- Update LLM Context files
  vim.api.nvim_create_user_command("ContextGroupUpdateLLM", function()
    if not ensure_llm_context() then
      return
    end

    if llm_ctx:update_files() then
      vim.notify("Updated LLM Context files")
    else
      vim.notify("Failed to update LLM Context files", vim.log.levels.ERROR)
    end
  end, {
    desc = "Update LLM Context files",
  })
end

return M
