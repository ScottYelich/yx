# YX Builds

This directory contains build workspaces for different YX implementations.

## Build Workspaces

Each build workspace is a complete implementation of YX in a specific language or configuration.

Example builds:
- `python-impl/` - Python implementation
- `swift-impl/` - Swift implementation
- `rust-impl/` - Rust implementation
- `go-impl/` - Go implementation

## Build Structure

Each build directory contains:
```
build-name/
├── BUILD_CONFIG.json    # Configuration from Step 0
├── BUILD_STATUS.md      # Progress tracking
├── SESSION.md           # Crash recovery (during build)
├── [source code]        # Implementation files
├── [tests]              # Test files
└── docs/
    └── build-history/   # Completed step records
```

## Creating a New Build

1. Create a new directory: `mkdir builds/<build-name>`
2. Navigate to build directory: `cd builds/<build-name>`
3. Point AI agent at system root with build name
4. AI executes Step 0 to create BUILD_CONFIG.json
5. AI executes Steps 1-N autonomously

## Current Builds

No builds created yet.
