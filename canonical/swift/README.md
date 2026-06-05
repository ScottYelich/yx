# Canonical Swift Implementation

This directory contains the **working reference implementation** of the YX protocol in Swift.

## Status

✅ **Complete** — Transport, Protocol 0 (Text/JSON-RPC), Protocol 1 (Binary:
compression / AES-256-GCM / chunking + reassembly), and security (replay
protection + rate limiting). 67 tests pass (`swift test`). Validates against the
Python canonical test vectors and interoperates with Python over real UDP (48/48).

## Layout

```
canonical/swift/
├── Sources/YXProtocol/  # Source code
│   ├── Transport/       # UDP, packet handling
│   │   ├── Packet.swift
│   │   ├── PacketBuilder.swift
│   │   └── UDPSocket.swift
│   └── Primitives/      # Core utilities
│       ├── GUIDFactory.swift
│       └── DataCrypto.swift
├── Tests/               # All XCTests
│   └── YXProtocolTests/
│       ├── Unit/
│       └── Integration/
├── Package.swift        # SPM configuration
└── README.md            # Documentation
```

## Purpose

This is the **canonical reference** for:
- Swift/iOS/macOS implementation
- Wire format compatibility with Python
- Cross-language validation
- High-performance implementation

## Wire Format Compatibility

**CRITICAL:** Swift implementation MUST produce byte-identical packets to Python.

This is verified in Step 9 (Canonical Artifact Validation):
- Loads `../test-vectors/text-protocol-packets.json`
- Validates HMAC matches Python's output
- Ensures full wire format compatibility

## Build Instructions

See `../../BUILD_WORKFLOW.md` for complete build and promotion process.

## Prerequisites

**Must be built AFTER Python:**
1. Python canonical implementation must exist
2. Canonical test vectors must be generated
3. Then Swift can be built and validated

## Not Yet Available

This implementation doesn't exist yet. To create it:

```bash
# First: Ensure Python is built and promoted
test -d ../python || echo "Build Python first!"

# Then: Build Swift
cd ../..
# Point AI at this directory
# Execute: "Build Swift implementation, start with Step 0"
```
