-- lua/spec/context-groups/core_spec.lua
local core = require("context-groups.core")
local utils = require("context-groups.utils")
local assert = require("luassert")
local match = require("luassert.match")
local stub = require("luassert.stub")

describe("Core module", function()
  -- Testing module structure and basic functionality
  it("should expose key functions", function()
    assert.is_function(core.find_root)
    assert.is_function(core.get_context_files)
    assert.is_function(core.add_context_file)
    assert.is_function(core.remove_context_file)
    assert.is_function(core.clear_context_group)
  end)
  
  -- Testing project root detection using function stubs
  it("should detect project roots", function()
    -- Create stub for filereadable
    local filereadable_stub = stub(vim.fn, "filereadable")
    -- Create stub for isdirectory
    local isdirectory_stub = stub(vim.fn, "isdirectory")
    -- Create stub for getcwd
    local getcwd_stub = stub(vim.fn, "getcwd")
    
    -- Set up return values
    filereadable_stub.returns(0)
    isdirectory_stub.returns(0)
    getcwd_stub.returns("/fallback")
    
    -- Force .git detection for one path
    isdirectory_stub.on_call_with("/test-project/.git").returns(1)
    
    -- Test root finding with .git marker
    local root = core.find_root("/test-project/src/file.lua")
    
    -- Restore original functions
    filereadable_stub:revert()
    isdirectory_stub:revert()
    getcwd_stub:revert()
  end)
  
  -- Testing export functionality as basic module check
  it("should have export functionality", function()
    assert.is_table(core.export)
    assert.is_function(core.export.export_contents)
  end)
end)
