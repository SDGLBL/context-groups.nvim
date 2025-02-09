local assert = require("luassert")
local go = require("context-groups.lsp.go")

describe("Go imports parser", function()
  -- 测试单行导入
  it("should parse single line import", function()
    local content = [[
package main

import "fmt"

func main() {
  fmt.Println("Hello, World!")
}
    ]]
    local bufnr = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))

    local imports = go.test.parse_imports(bufnr)
    assert.equals(1, #imports)
    assert.equals("fmt", imports[1].package)
    assert.equals(2, imports[1].line)
    assert.equals(8, imports[1].character)
  end)

  -- 测试导入块
  it("should parse import block", function()
    local content = [[
package main

import (
  "fmt"
  "os"
)

func main() {
  fmt.Println("Hello, World!")
  os.Exit(0)
}
    ]]

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))

    local imports = go.test.parse_imports(bufnr)
    assert.equals(2, #imports)
    assert.equals("fmt", imports[1].package)
    assert.equals(3, imports[1].line)
    -- assert.equals(2, imports[1].character)
    assert.equals("os", imports[2].package)
    assert.equals(4, imports[2].line)
    -- assert.equals(2, imports[2].character)
  end)

  -- 测试命名导入
  it("should parse named import", function()
    local content = [[
package main

import (
  myfmt "fmt"
  "os"
)

func main() {
  myfmt.Println("Hello, World!")
  os.Exit(0)
}
    ]]

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))

    local imports = go.test.parse_imports(bufnr)
    assert.equals(2, #imports)
    assert.equals("fmt", imports[1].package)
    assert.equals("myfmt", imports[1].alias)
    assert.equals(3, imports[1].line)
    -- assert.equals(2, imports[1].character)
    assert.equals("os", imports[2].package)
    assert.equals(4, imports[2].line)
    -- assert.equals(2, imports[2].character)
  end)

  -- 测试空白导入
  it("should parse blank import", function()
    local content = [[
package main

import (
  _ "fmt"
  "os"
)

func main() {
  os.Exit(0)
}
    ]]

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))

    local imports = go.test.parse_imports(bufnr)
    assert.equals(2, #imports)
    assert.equals("fmt", imports[1].package)
    assert.is_nil(imports[1].alias)
    assert.equals(3, imports[1].line)
    -- assert.equals(2, imports[1].character)
    assert.equals("os", imports[2].package)
    assert.equals(4, imports[2].line)
    -- assert.equals(2, imports[2].character)
  end)

  -- 测试带有注释的导入
  it("should handle comments in imports", function()
    local content = [[
package main

import (
  // fmt is used for printing
  "fmt"
  // os is used for system operations
  "os"
)

func main() {
  fmt.Println("Hello, World!")
  os.Exit(0)
}
    ]]

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))

    local imports = go.test.parse_imports(bufnr)
    assert.equals(2, #imports)
    assert.equals("fmt", imports[1].package)
    assert.equals(4, imports[1].line)
    -- assert.equals(2, imports[1].character)
    assert.equals("os", imports[2].package)
    assert.equals(6, imports[2].line)
    -- assert.equals(2, imports[2].character)
  end)

  -- 测试混合导入
  it("should parse mixed imports", function()
    local content = [[
package main

import "fmt"
import (
  "os"
  myfmt "fmt"
)

func main() {
  fmt.Println("Hello, World!")
  os.Exit(0)
  myfmt.Println("Another print")
}
    ]]

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))

    local imports = go.test.parse_imports(bufnr)
    assert.equals(3, #imports)
    assert.equals("fmt", imports[1].package)
    assert.equals(2, imports[1].line)
    -- assert.equals(8, imports[1].character)
    assert.equals("os", imports[2].package)
    assert.equals(4, imports[2].line)
    -- assert.equals(2, imports[2].character)
    assert.equals("fmt", imports[3].package)
    assert.equals("myfmt", imports[3].alias)
    assert.equals(5, imports[3].line)
    -- assert.equals(2, imports[3].character)
  end)
end)
