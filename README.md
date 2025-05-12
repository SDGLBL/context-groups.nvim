# Context-Groups.nvim

A Neovim plugin for managing context files for AI-assisted coding.

## Overview

Context Groups is a Neovim plugin designed to enhance AI-assisted coding by managing context files on a per-buffer basis. It allows users to maintain groups of related files that provide additional context for AI models like Claude, GPT, and others.

## Features

- Per-buffer context group management
- Project-level configuration persistence
- Automatic project root detection
- Telescope integration for file selection and preview
- LSP integration for intelligent imports
- Enhanced diagnostics and code sharing:
  - Inline LSP diagnostics with code context
  - Git diff integration for tracking changes
  - Buffer path utilities for easy reference

## Installation

### Using packer.nvim

```lua
use {
  'username/context-groups.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
  }
}
```

### Using lazy.nvim

```lua
{
  'username/context-groups.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
  }
}
```

## Setup

Basic setup with default settings:

```lua
require('context-groups').setup()
```

Setup with custom configuration:

```lua
require('context-groups').setup({
  keymaps = {
    add_context = "<leader>ca",
    show_context = "<leader>cs",
    code2prompt = "<leader>cy",
    lsp_diagnostics_current = "<leader>cl",
    lsp_diagnostics_all = "<leader>cL",
  },
  storage_path = vim.fn.stdpath("data") .. "/context-groups",
  import_prefs = {
    show_stdlib = false,
    show_external = false,
    ignore_patterns = {},
  },
  project_markers = {
    ".git",
    ".svn",
    "package.json",
    "Cargo.toml",
    "go.mod",
    "requirements.txt",
  },
})
```

## Usage

### Basic Workflow

1. Add files to context group:
   - Use `:ContextGroupAdd` command or press `<leader>ca`
   - Select files using Telescope interface
   - Press <CR> to add a file or <C-Space> to add without closing

2. View current context group:
   - Use `:ContextGroupShow` command or press `<leader>cs`
   - Preview file contents
   - Remove files using <C-d>
   - Open files in split with <C-v>

3. Add imports to context group:
   - Use `:ContextGroupAddImports` command
   - Filter by external/stdlib using <C-e>/<C-t>
   - Select imports to add to context group

4. Get enhanced code context:
   - Copy buffer content with LSP diagnostics: `:ContextGroupLSPDiagnosticsInlineCurrent` or `<leader>cI`
   - Copy all buffers with LSP diagnostics: `:ContextGroupLSPDiagnosticsInlineAll` or `<leader>cA`
   - Copy buffer with Git diff comparison: `:ContextGroupGitDiffCurrent` or `<leader>cg`
   - Copy all modified buffers with Git diffs: `:ContextGroupGitDiffAllModified` or `<leader>cG`
   - Copy all buffer paths: `:ContextGroupCopyBufferPaths` or `<leader>cp`

5. Format code for AI tools:
   - Use `:ContextGroupBuffer2Prompt` or `<leader>cy` to format open buffer contents for sharing with AI tools

## Recent Updates

- **May 2025**: Added Git diff integration for tracking file changes and comparing with Git history.
- **May 2025**: Added inline LSP diagnostics feature for enhanced error visualization within code context.
- **May 2025**: Added buffer paths utilities for easy reference and sharing.
- **March 2025**: Enhanced buffer formatting for better AI tool integration.
- **February 2025**: Major refactoring to improve code organization and maintainability.

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
