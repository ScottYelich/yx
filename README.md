# YX System

**YX** is a secure, payload-agnostic UDP-based networking protocol with HMAC integrity, optional encryption/compression, and chunked delivery for large messages.

## Overview

YX provides a lightweight, secure transport layer for distributed systems:
- UDP broadcast-based communication
- HMAC-SHA256 packet integrity
- Optional AES-256-GCM encryption
- Optional ZLIB compression
- Multi-packet chunking for large messages
- Channel-based message isolation (65K channels)
- Cross-platform wire format (Python/Swift parity)

## This is a YBS System

This directory follows the [YBS (Yelich Build System)](https://github.com/ScottYelich/ybs) structure:

- `specs/` - Specifications defining WHAT YX is and does
- `steps/` - Build steps defining HOW to implement YX (organized by language)
- `builds/` - Build workspaces for different YX implementations
- `canonical/` - Shared reference artifacts for cross-implementation validation
- `tests/` - System-level and interoperability tests
- `docs/` - Additional documentation

Learn more about YBS: https://github.com/ScottYelich/ybs

## Multi-Language Implementation

YX is designed to have implementations in multiple languages with guaranteed wire format compatibility:

### Primary Implementations
- **Python** (`builds/python-impl/`) - Reference implementation, generates canonical test vectors
- **Swift** (`builds/swift-impl/`) - High-performance implementation, validates against canonical test vectors

### Build Order
1. **Python first** - Generates canonical artifacts in `canonical/`
2. **Swift second** - Validates against Python's canonical artifacts
3. **Interop tests** - Verifies Python ↔ Swift communication (`tests/interop/`)

All implementations must produce byte-identical packets for the same inputs.

## Getting Started

### Building Python Implementation
```bash
cd builds/python-impl/
# AI agent executes steps/python/ sequence
# Generates canonical artifacts to ../../canonical/
```

### Building Swift Implementation
```bash
cd builds/swift-impl/
# AI agent executes steps/swift/ sequence
# Validates against ../../canonical/ test vectors
```

### Running Interop Tests
```bash
cd tests/interop/
./test-all-interop.sh
```

## Current Status

- ✅ Protocol specification complete (`specs/technical/yx-protocol-spec.md`)
- ✅ Testing strategy defined (`specs/testing/testing-strategy.md`)
- ✅ Language guidance documented (`specs/architecture/implementation-languages.md`)
- ✅ Multi-language structure established (`canonical/`, `tests/interop/`, language-specific steps)
- ⏳ Step 0 (Build Configuration) - Not yet created
- ⏳ Python build steps - Not yet created
- ⏳ Swift build steps - Not yet created
- ⏳ No implementations built yet

## Reference Documentation

- `docs/ybs-overview.md` - Introduction to YBS framework
- `docs/ybs-framework-spec.md` - Complete YBS framework specification
- `specs/technical/yx-protocol-spec.md` - YX UDP protocol specification
