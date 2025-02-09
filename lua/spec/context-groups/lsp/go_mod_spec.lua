-- lua/spec/context-groups/lsp/go_mod_spec.lua

local assert = require("luassert")
local go = require("context-groups.lsp.go")

-- 辅助函数：创建临时的 go.mod 文件
local function create_test_mod_file(content)
  -- 创建临时文件
  local tmp_dir = vim.fn.fnamemodify(vim.fn.tempname(), ":h")
  local mod_path = tmp_dir .. "/go.mod"

  -- 写入内容
  local f = io.open(mod_path, "w")
  if not f then
    error("Failed to create temporary go.mod file")
  end
  f:write(content)
  f:close()

  -- Debug 输出
  -- vim.notify("========== Test File Content ==========", vim.log.levels.INFO)
  -- vim.notify("Content to write:\n" .. content, vim.log.levels.INFO)
  -- local written = vim.fn.readfile(mod_path)
  -- vim.notify("Content after write:\n" .. vim.inspect(written), vim.log.levels.INFO)
  -- vim.notify("======================================", vim.log.levels.INFO)

  return mod_path
end

-- 辅助函数：清理临时文件和缓存
local function cleanup_test_mod_file(mod_path)
  os.remove(mod_path)
  -- 清除缓存以确保每个测试都是独立的
  go.test.clear_cache()
end

describe("Go mod parser", function()
  -- 测试基本的模块声明
  it("should parse basic module declaration", function()
    local content = [[
module example.com/my/module

go 1.16
    ]]

    local mod_path = create_test_mod_file(content)
    local mod_info = go.test.parse_go_mod(mod_path)
    cleanup_test_mod_file(mod_path)

    assert.equals("example.com/my/module", mod_info.module)
    assert.same({}, mod_info.requires)
    assert.same({}, mod_info.replaces)
  end)

  -- 测试带有单个依赖的模块
  it("should parse module with single require", function()
    local content = [[
module example.com/my/module

go 1.16

require github.com/pkg/errors v0.9.1
    ]]

    local mod_path = create_test_mod_file(content)
    local mod_info = go.test.parse_go_mod(mod_path)
    cleanup_test_mod_file(mod_path)

    assert.equals("example.com/my/module", mod_info.module)
    assert.equals("v0.9.1", mod_info.requires["github.com/pkg/errors"])
  end)

  -- 测试带有多个依赖的模块
  it("should parse module with multiple requires", function()
    local content = [[
module example.com/my/module

go 1.16

require (
    github.com/pkg/errors v0.9.1
    golang.org/x/sync v0.0.0-20210220032951-036812b2e83c
    gopkg.in/yaml.v2 v2.4.0 // indirect
)
    ]]

    local mod_path = create_test_mod_file(content)
    local mod_info = go.test.parse_go_mod(mod_path)
    cleanup_test_mod_file(mod_path)

    assert.equals("example.com/my/module", mod_info.module)
    assert.equals("v0.9.1", mod_info.requires["github.com/pkg/errors"])
    assert.equals("v0.0.0-20210220032951-036812b2e83c", mod_info.requires["golang.org/x/sync"])
    assert.equals("v2.4.0", mod_info.requires["gopkg.in/yaml.v2"])
  end)

  -- 测试带有替换指令的模块
  it("should parse module with replace directives", function()
    local content = [[
module example.com/my/module

go 1.16

require example.com/some/dependency v1.2.3

replace example.com/some/dependency => example.com/fork/dependency v1.2.3-custom
    ]]

    local mod_path = create_test_mod_file(content)
    local mod_info = go.test.parse_go_mod(mod_path)
    cleanup_test_mod_file(mod_path)

    assert.equals("example.com/my/module", mod_info.module)
    assert.equals("v1.2.3", mod_info.requires["example.com/some/dependency"])
    assert.equals("example.com/fork/dependency v1.2.3-custom", mod_info.replaces["example.com/some/dependency"])
  end)

  -- 测试带有注释的模块
  it("should handle comments correctly", function()
    local content = [[
// This is a module comment
module example.com/my/module // Module path

// Dependencies below
require (
    // Direct dependency
    github.com/pkg/errors v0.9.1
    // Indirect dependency
    gopkg.in/yaml.v2 v2.4.0 // indirect
)

// Replace directive
replace example.com/old => example.com/new v1.0.0 // Custom version
    ]]

    local mod_path = create_test_mod_file(content)
    local mod_info = go.test.parse_go_mod(mod_path)
    cleanup_test_mod_file(mod_path)

    assert.equals("example.com/my/module", mod_info.module)
    assert.equals("v0.9.1", mod_info.requires["github.com/pkg/errors"])
    assert.equals("v2.4.0", mod_info.requires["gopkg.in/yaml.v2"])
    assert.equals("example.com/new v1.0.0", mod_info.replaces["example.com/old"])
  end)

  -- 测试复杂的模块名称
  it("should handle complex module names", function()
    local content = [[
module k8s.io/kubernetes/pkg/api/v1beta1

require (
    k8s.io/api v0.21.0
    k8s.io/apimachinery v0.21.0
    k8s.io/client-go v0.21.0
)
    ]]

    local mod_path = create_test_mod_file(content)
    local mod_info = go.test.parse_go_mod(mod_path)
    cleanup_test_mod_file(mod_path)

    assert.equals("k8s.io/kubernetes/pkg/api/v1beta1", mod_info.module)
    assert.equals("v0.21.0", mod_info.requires["k8s.io/api"])
    assert.equals("v0.21.0", mod_info.requires["k8s.io/apimachinery"])
    assert.equals("v0.21.0", mod_info.requires["k8s.io/client-go"])
  end)

  -- 测试空的 go.mod 文件
  it("should handle empty go.mod file", function()
    local content = ""

    local mod_path = create_test_mod_file(content)
    local mod_info = go.test.parse_go_mod(mod_path)
    cleanup_test_mod_file(mod_path)

    assert.is_nil(mod_info.module)
    assert.same({}, mod_info.requires)
    assert.same({}, mod_info.replaces)
  end)

  -- 测试缓存功能
  it("should cache parsed mod files", function()
    local content = [[
module example.com/my/module

require github.com/pkg/errors v0.9.1
    ]]

    local mod_path = create_test_mod_file(content)

    -- 首次解析
    local first_parse = go.test.parse_go_mod(mod_path)

    -- 修改文件内容（但不应影响缓存的结果）
    local f = io.open(mod_path, "w")
    f:write("module different.com/module")
    f:close()

    -- 第二次解析应该返回缓存的结果
    local second_parse = go.test.parse_go_mod(mod_path)

    cleanup_test_mod_file(mod_path)

    assert.equals(first_parse.module, second_parse.module)
    assert.same(first_parse.requires, second_parse.requires)
  end)

  -- 测试带有多个 require 和 replace 块的模块
  it("should parse multiple require and replace blocks", function()
    local content = [[
module example.com/my/module

require github.com/pkg/errors v0.9.1

require (
    golang.org/x/sync v0.0.0-20210220032951-036812b2e83c
    gopkg.in/yaml.v2 v2.4.0
)

replace example.com/old => example.com/new v1.0.0

replace (
    k8s.io/api => k8s.io/api v0.20.0
    k8s.io/client-go => k8s.io/client-go v0.20.0
)
    ]]

    local mod_path = create_test_mod_file(content)
    local mod_info = go.test.parse_go_mod(mod_path)
    cleanup_test_mod_file(mod_path)

    -- 验证 requires
    assert.equals("v0.9.1", mod_info.requires["github.com/pkg/errors"])
    assert.equals("v0.0.0-20210220032951-036812b2e83c", mod_info.requires["golang.org/x/sync"])
    assert.equals("v2.4.0", mod_info.requires["gopkg.in/yaml.v2"])

    -- 验证 replaces
    assert.equals("example.com/new v1.0.0", mod_info.replaces["example.com/old"])
    assert.equals("k8s.io/api v0.20.0", mod_info.replaces["k8s.io/api"])
    assert.equals("k8s.io/client-go v0.20.0", mod_info.replaces["k8s.io/client-go"])
  end)

  -- 测试错误处理
  it("should handle malformed go.mod files", function()
    local content = [[
module example.com/my/module

require (
    github.com/pkg/errors    // missing version
    golang.org/x/sync v0.0.0-20210220032951-036812b2e83c
)
    ]]

    local mod_path = create_test_mod_file(content)
    local mod_info = go.test.parse_go_mod(mod_path)
    cleanup_test_mod_file(mod_path)

    assert.equals("example.com/my/module", mod_info.module)
    -- 应该跳过格式错误的行，但正确解析其他行
    assert.equals("v0.0.0-20210220032951-036812b2e83c", mod_info.requires["golang.org/x/sync"])
  end)
end)
