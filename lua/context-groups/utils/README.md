# YAML Implementation for Context Groups

## Implementation Details

This module only uses the Rust implementation for YAML parsing and encoding. The pure Lua implementation has been removed in favor of a more efficient and consistent approach.

## Testing

A mock implementation is provided for testing purposes when the Rust library is not available. This should NOT be used in production and is only meant to make the tests pass.

## Dependencies

- The Rust implementation requires FFI support in Neovim
- JSON module (cjson or dkjson) is required for the Rust implementation
- The Rust library needs to be built and available in the search path

## Building the Rust library

To build the Rust library:

```bash
cd /Users/lijie/project/context-groups.nvim
make rust
```

This will compile the Rust library and place it in the appropriate location.
