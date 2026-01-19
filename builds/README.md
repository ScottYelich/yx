# YX Builds

This directory contains build workspaces for different YX implementations.

## Build Workspaces

Each build workspace is a complete implementation of YX in a specific language or configuration.

### Primary Implementations
- `python-impl/` - Python implementation (reference, generates canonical artifacts)
- `swift-impl/` - Swift implementation (validates against canonical artifacts)

### Future Implementations
- `rust-impl/` - Rust implementation (planned)
- `go-impl/` - Go implementation (planned)

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

## Build Order

When building multiple implementations:

1. **Python first** (`python-impl/`)
   - Generates canonical test vectors → `../canonical/test-vectors/`
   - Generates reference packets → `../canonical/reference-packets/`
   - Generates benchmarks → `../canonical/benchmarks/`

2. **Swift second** (`swift-impl/`)
   - Validates against canonical test vectors
   - Ensures wire format compatibility with Python
   - Generates own benchmarks for comparison

3. **Interop tests** (`../tests/interop/`)
   - Run after both implementations complete
   - Verify Python ↔ Swift message exchange
   - Confirm identical packet generation

## Current Builds

No builds created yet. Builds will be created by executing Step 0 and following language-specific build steps.
