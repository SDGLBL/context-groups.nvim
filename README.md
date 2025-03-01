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
- LLM Context integration for profile-based context management

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
    add_imports = "<leader>ci",
    update_llm = "<leader>cr",
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
   - Use `:ContextGroupAddImports` command or press `<leader>ci`
   - Filter by external/stdlib using <C-e>/<C-t>
   - Select imports to add to context group

4. Send context to LLM:
   - Use built-in support for LLM Context
   - Initialize with `:ContextGroupInitLLM`
   - Select profiles with `:ContextGroupSwitchProfile`
   - Sync context with `:ContextGroupSync`

## LLM Context Integration

Context Groups integrates with [LLM Context](https://github.com/cyberchitta/llm-context.py/) to provide advanced context management for LLMs. The plugin now supports the latest YAML configuration format along with backward compatibility for TOML.

### Setup

1. Install LLM Context:
   ```bash
   uv tool install llm-context
   ```

2. Initialize in your project:
   ```
   :ContextGroupInitLLM
   ```

3. Manage profiles:
   ```
   :ContextGroupSwitchProfile            # Switch profiles
   :ContextGroupCreateProfile {name}     # Create new profile
   :ContextGroupSync                     # Sync context files
   ```

   When creating a new profile, it automatically inherits from the "code" base profile, ensuring consistent settings while allowing for customization. For example:
   ```
   :ContextGroupCreateProfile my-feature
   ```
   This creates a new profile named "my-feature" with the same settings as the "code" profile but with your current buffer files included.

## Recent Updates

- **March 2025**: Enhanced profile creation to automatically use the "code" profile as a base for better reusability.
- **February 2025**: Added support for YAML configuration in LLM Context integration. See [YAML Migration Guide](docs/yaml-migration.md) for details.
- **February 2025**: Major refactoring to improve code organization and maintainability. See [REFACTORING.md](REFACTORING.md) for details.

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
