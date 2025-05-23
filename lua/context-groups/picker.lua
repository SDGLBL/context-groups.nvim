-- lua/context-groups/picker.lua
-- Enhanced telescope integration, refactored from ui/picker.lua

local config = require("context-groups.config")
local core = require("context-groups.core")
local lsp = require("context-groups.lsp")

local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local previewers = require("telescope.previewers")

local M = {}

-- Store the buffer number that initiated the picker
local source_bufnr = nil

-- Create a file previewer
local function create_previewer()
  return previewers.new_buffer_previewer({
    title = "File Preview",
    define_preview = function(self, entry)
      local content = require("context-groups.utils").read_file_content(entry.path)
      if not content then
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "File not readable" })
        return
      end

      local lines = vim.split(content, "\n")
      local max_lines = config.get().max_preview_lines or 500

      -- Limit number of preview lines
      if #lines > max_lines then
        lines = vim.list_slice(lines, 1, max_lines)
        table.insert(lines, "... (preview truncated)")
      end

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

      -- Set filetype for syntax highlighting
      local ft = vim.filetype.match({ filename = entry.path })
      if ft then
        vim.bo[self.state.bufnr].filetype = ft
      end
    end,
  })
end

-- Refresh picker while preserving mode
local function refresh_picker(prompt_bufnr, current_mode, picker_fn)
  actions.close(prompt_bufnr)
  picker_fn()
  -- Delay mode switch to ensure picker is fully initialized
  vim.schedule(function()
    if current_mode == "i" then
      vim.cmd("startinsert")
    end
  end)
end

-- Show picker for adding files to context group
function M.show_file_picker()
  -- Store the source buffer number
  source_bufnr = vim.api.nvim_get_current_buf()

  local project_files = core.get_project_files(source_bufnr)

  pickers
    .new(config.get().telescope_theme, {
      prompt_title = "Add to Context Group",
      finder = finders.new_table({
        results = project_files,
        entry_maker = function(entry)
          return {
            value = entry,
            display = vim.fn.fnamemodify(entry, ":~:."),
            ordinal = entry,
            path = entry,
          }
        end,
      }),
      previewer = create_previewer(),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        -- Add file(s) to context group
        local function add_files(close)
          local selection = action_state.get_selected_entry()

          if selection then
            local success = core.add_context_file(selection.value, source_bufnr)
            if success then
              vim.notify(string.format("Added %s to context group", selection.display))
            end
          end

          if close then
            actions.close(prompt_bufnr)
          end
        end

        -- Add and close
        map("i", "<CR>", function()
          add_files(true)
        end)

        -- Add and continue
        map("i", "<C-Space>", function()
          add_files(false)
        end)

        return true
      end,
    })
    :find()
end

-- Show current context group
function M.show_context_group()
  -- Store the source buffer number
  source_bufnr = vim.api.nvim_get_current_buf()

  local context_files = core.get_context_files(source_bufnr)

  pickers
    .new(config.get().telescope_theme, {
      prompt_title = "Context Group",
      finder = finders.new_table({
        results = context_files,
        entry_maker = function(entry)
          return {
            value = entry,
            display = vim.fn.fnamemodify(entry, ":~:."),
            ordinal = entry,
            path = entry,
          }
        end,
      }),
      previewer = create_previewer(),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        -- Remove file from context group
        map("i", "<C-d>", function()
          local selection = action_state.get_selected_entry()
          if selection then
            local success = core.remove_context_file(selection.value, source_bufnr)
            if success then
              vim.notify(string.format("Removed %s from context group", selection.display))
              -- Get current mode
              local current_mode = vim.api.nvim_get_mode().mode
              refresh_picker(prompt_bufnr, current_mode, M.show_context_group)
            end
          end
        end)

        -- Open file in split
        map("i", "<C-v>", function()
          local selection = action_state.get_selected_entry()
          if selection then
            actions.close(prompt_bufnr)
            vim.cmd("vsplit " .. vim.fn.fnameescape(selection.value))
          end
        end)

        -- Copy path to clipboard
        map("i", "<C-y>", function()
          local selection = action_state.get_selected_entry()
          if selection then
            vim.fn.setreg("+", selection.value)
            vim.notify("Copied path to clipboard")
          end
        end)

        return true
      end,
    })
    :find()
end

-- Show imports picker
function M.show_imports_picker()
  -- Store the source buffer number
  source_bufnr = vim.api.nvim_get_current_buf()

  local imported_files = lsp.get_imported_files(source_bufnr)

  -- Create custom entry maker for import display
  local function make_import_entry(entry)
    local display_type = ""
    if entry.is_stdlib then
      display_type = " [stdlib]"
    elseif entry.is_external then
      display_type = " [external]"
    end

    local display = string.format("%s%s (%s)", entry.name, display_type, entry.language)

    return {
      value = entry,
      display = display,
      ordinal = entry.name,
      path = entry.path,
    }
  end

  -- Create custom previewer for imports
  local import_previewer = previewers.new_buffer_previewer({
    title = "Import Preview",
    define_preview = function(self, entry)
      if entry.value.parse_error then
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
          "Error: " .. (entry.value.error_message or "Unknown error"),
          "",
          "Import path: " .. entry.value.import_path,
          "Language: " .. entry.value.language,
        })
        return
      end

      -- Show file content if available
      if vim.fn.filereadable(entry.path) == 1 then
        local content = require("context-groups.utils").read_file_content(entry.path)
        if not content then
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "File not readable" })
          return
        end

        local lines = vim.split(content, "\n")
        local max_lines = config.get().max_preview_lines or 500

        if #lines > max_lines then
          lines = vim.list_slice(lines, 1, max_lines)
          table.insert(lines, "... (preview truncated)")
        end

        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

        local ft = vim.filetype.match({ filename = entry.path })
        if ft then
          vim.bo[self.state.bufnr].filetype = ft
        end
      else
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
          "File not readable: " .. entry.path,
          "",
          "Import path: " .. entry.value.import_path,
          "Language: " .. entry.value.language,
        })
      end
    end,
  })

  -- Create import picker
  pickers
    .new(config.get().telescope_theme, {
      prompt_title = "Add Imports to Context Group",
      finder = finders.new_table({
        results = imported_files,
        entry_maker = make_import_entry,
      }),
      previewer = import_previewer,
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        -- Add import(s) to context group
        local function add_imports(close)
          local selection = action_state.get_selected_entry()
          if selection then
            if not selection.value.parse_error and selection.value.path ~= "" then
              local success = core.add_context_file(selection.value.path, source_bufnr)
              if success then
                vim.notify(string.format("Added %s to context group", selection.value.name))
              end
            else
              vim.notify(
                string.format("Skipped %s: %s", selection.value.name, selection.value.error_message or "Invalid import"),
                vim.log.levels.WARN
              )
            end
          end

          if close then
            actions.close(prompt_bufnr)
          end
        end

        -- Add and close
        map("i", "<CR>", function()
          add_imports(true)
        end)

        -- Add and continue
        map("i", "<C-Space>", function()
          add_imports(false)
        end)

        -- Toggle stdlib visibility
        map("i", "<C-t>", function()
          local prefs = config.get_import_prefs()
          prefs.show_stdlib = not prefs.show_stdlib
          config.update_import_prefs(prefs)

          local current_mode = vim.api.nvim_get_mode().mode
          refresh_picker(prompt_bufnr, current_mode, M.show_imports_picker)
        end)

        -- Toggle external deps visibility
        map("i", "<C-e>", function()
          local prefs = config.get_import_prefs()
          prefs.show_external = not prefs.show_external
          config.update_import_prefs(prefs)

          local current_mode = vim.api.nvim_get_mode().mode
          refresh_picker(prompt_bufnr, current_mode, M.show_imports_picker)
        end)

        return true
      end,
    })
    :find()
end

return M

