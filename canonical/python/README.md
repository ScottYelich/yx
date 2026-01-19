# Canonical Python Implementation

This directory contains the **working reference implementation** of the YX protocol in Python.

## Status

⏳ **Not yet built**

This directory will be populated after:
1. Building the Python implementation in `builds/python-impl/`
2. Running all tests (100% pass, ≥80% coverage)
3. Generating canonical test vectors
4. Promoting the working code here

## What Will Be Here

After promotion from `builds/python-impl/`:

```
canonical/python/
├── yx/                  # Source code
│   ├── transport/       # UDP, packet handling
│   │   ├── packet.py
│   │   ├── packet_builder.py
│   │   └── udp_socket.py
│   └── primitives/      # Core utilities
│       ├── guid_factory.py
│       └── data_crypto.py
├── tests/               # All tests
│   ├── unit/
│   └── integration/
├── pyproject.toml       # Configuration
└── README.md            # Documentation
```

## Purpose

This is the **canonical reference** for:
- Wire format specification (living code)
- Test vector generation
- Cross-language validation
- Documentation through working code

Other language implementations (Swift, Rust, Go) will validate against this reference.

## Build Instructions

See `../../BUILD_WORKFLOW.md` for complete build and promotion process.

## Not Yet Available

This implementation doesn't exist yet. To create it:

```bash
cd ../..
# Point AI at this directory
# Execute: "Build Python implementation, start with Step 0"
```
