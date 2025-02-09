-- lua/context-groups/ui/commands.lua

local config = require("context-groups.config")
local core = require("context-groups.core")
local picker = require("context-groups.ui.picker")

local M = {}

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
end

return M
