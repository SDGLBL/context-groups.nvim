-- lua/context-groups/llm/init_llm.lua
-- Implementation of LLM Context initialization with additional profiles

local M = {}

-- Initialize llm-context and create custom profiles
function M.init_llm_context()
  local LLMContext = require("context-groups.llm")
  local project = require("context-groups.core")
  local utils = require("context-groups.utils")

  -- Get project root
  local root = project.find_root(vim.fn.expand("%:p"))
  local llm_ctx = LLMContext.new(root)

  -- Initialize llm-context if needed
  if not llm_ctx:is_initialized() then
    vim.notify("Initializing LLM Context...", vim.log.levels.INFO)
    local success = llm_ctx:initialize()

    if not success then
      vim.notify("Failed to initialize LLM Context", vim.log.levels.ERROR)
      return false
    end

    vim.notify("LLM Context initialized successfully", vim.log.levels.INFO)
  else
    vim.notify("LLM Context already initialized", vim.log.levels.INFO)
  end

  -- Read the current config
  local config = llm_ctx.profile_manager:read_config()
  if not config then
    vim.notify("Failed to read LLM Context configuration", vim.log.levels.ERROR)
    return false
  end

  -- Add "buffer" profile if it doesn't exist
  if not config.profiles.buffer then
    vim.notify("Creating 'buffer' profile...", vim.log.levels.INFO)

    -- Create buffer profile based on current buffer
    config.profiles.buffer = {
      base = "code",
      ["only-include"] = {
        full_files = {
          "**/*",
        },
        outline_files = {
          "**/*",
        },
      },
    }
  end

  -- Add "doc" profile if it doesn't exist
  if not config.profiles.doc then
    vim.notify("Creating 'doc' profile...", vim.log.levels.INFO)

    -- Create documentation profile
    config.profiles.doc = {
      base = "code",
      ["only-include"] = {
        full_files = {
          "**/*.md",
          "**/*.txt", -- Documentation files
          "README*", -- Project info
          "LICENSE*",
        },
        outline_files = {
          "**/*.md",
          "**/*.txt",
          "README*",
          "LICENSE*",
        },
      },
    }
  end

  -- Write updated configuration
  local success = llm_ctx.profile_manager:write_config(config)
  if not success then
    vim.notify("Failed to write updated LLM Context configuration", vim.log.levels.ERROR)
    return false
  end

  vim.notify("LLM Context profiles created: code, buffer, doc", vim.log.levels.INFO)
  return true
end

return M
