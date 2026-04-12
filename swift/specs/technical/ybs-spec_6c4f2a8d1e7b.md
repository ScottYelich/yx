---
name: Swift Implementation Design
description: Swift-specific module structure, CryptoKit usage, SPM configuration, concurrency model, and design decisions for the YX protocol implementation
type: technical
guid: 6c4f2a8d1e7b
version: 0.1.0
status: Implemented
last_updated: 2026-04-11
---

# Specification: Swift Implementation Design

**GUID**: `6c4f2a8d1e7b`
**Version**: 0.1.0
**Status**: Implemented
**Last Updated**: 2026-04-11

## Overview

Captures design decisions specific to the Swift implementation of the YX protocol.
Records the *why* behind Swift-specific choices. Protocol requirements are in
`../../../protocol/specs/`; this spec covers only what is Swift-specific.

## Goals and Non-Goals

### Goals

- Document CryptoKit framework selection rationale
- Record the Swift Package Manager target structure
- Define concurrency model choices
- Specify Swift version constraints
- Document the UDP implementation approach (Network framework vs. BSD sockets)

### Non-Goals

- Does not define the wire format
- Does not define test coverage requirements (see `swift/specs/testing/`)
- Does not prescribe the Python or other implementations

## Dependencies

### System Frameworks (No Third-Party Dependencies)

| Framework | Purpose |
|---|---|
| `CryptoKit` | HMAC-SHA256, AES-256-GCM |
| `Network` | UDP via NWConnection/NWListener |
| `Foundation` | `Data`, `UUID`, `Date` |

### Why `CryptoKit` and not alternatives

| Option | Rejected Reason |
|---|---|
| CommonCrypto | C-level API, not Swifty, harder constant-time guarantees |
| OpenSSL via SPM | External dependency, compilation complexity, not needed |
| `swift-crypto` (open source) | Third-party; CryptoKit is Apple-native and available on all Apple platforms |
| CryptoKit (chosen) | Native, Swift-idiomatic, hardware-accelerated on Apple Silicon, constant-time by design |

### Why `Network` framework and not BSD sockets

| Option | Rejected Reason |
|---|---|
| POSIX `socket()` / `sendto()` | Requires bridging to C, UnsafePointers, more boilerplate |
| `Network.NWConnection` (chosen) | Swift-native API, async/await compatible, automatic path monitoring |

## Requirements

### Functional Requirements

**FR-1**: Swift Package Manager Target Structure
- **Description**: Package.swift defines library, test, and executable targets
- **Priority**: High
- **Acceptance Criteria**:
  - [ ] `YXProtocol` library target in `Sources/YXProtocol/`
  - [ ] `YXProtocolTests` test target in `Tests/YXProtocolTests/`
  - [ ] `SwiftSender` and `SwiftReceiver` executable targets for interop testing
  - [ ] No embedded Xcode project files

**FR-2**: Value-Typed Packet
- **Description**: `Packet` is a Swift `struct`, not a `class`
- **Priority**: High
- **Acceptance Criteria**:
  - [ ] `struct Packet` with `hmac: Data`, `guid: Data`, `payload: Data`
  - [ ] Packet instances are passed by value (copy semantics)
  - [ ] `Packet` conforms to `Equatable` and `Sendable`

**FR-3**: CryptoKit HMAC Implementation
- **Description**: HMAC uses `CryptoKit.HMAC<SHA256>`
- **Priority**: Critical
- **Acceptance Criteria**:
  - [ ] `HMAC<SHA256>.authenticationCode(for:using:)` used for computation
  - [ ] Result truncated to first 16 bytes
  - [ ] Comparison uses `HMAC.isValidAuthenticationCode(_:authenticating:using:)` for constant-time

**FR-4**: Actor-Based Shared State
- **Description**: Replay window and rate limiter use Swift `actor`
- **Priority**: High
- **Acceptance Criteria**:
  - [ ] `actor ReplayWindow` for seen-GUID tracking
  - [ ] `actor RateLimiter` for per-sender request counting
  - [ ] No `@unchecked Sendable` workarounds — proper actor isolation

**FR-5**: Byte-Identical Output with Python
- **Description**: For identical inputs, Swift and Python produce identical bytes
- **Priority**: Critical
- **Acceptance Criteria**:
  - [ ] All canonical test vectors pass (zero failures)
  - [ ] HMAC bytes identical to Python output
  - [ ] Packet serialization order identical: HMAC || GUID || PAYLOAD

### Non-Functional Requirements

**NFR-1**: Swift Version
- **Description**: Implementation builds with Swift 5.9+
- **Metric**: `swift --version`
- **Target**: 5.9 ≤ version

**NFR-2**: Zero Third-Party Dependencies
- **Description**: `Package.swift` has no external package dependencies
- **Metric**: `swift package show-dependencies`
- **Target**: Zero external packages

**NFR-3**: Build Time
- **Description**: Full build completes reasonably fast
- **Metric**: `swift build` wall-clock time
- **Target**: <60 seconds on Apple Silicon

## Architecture

### Package Target Dependency Graph

```
SwiftSender (executable) ──┐
                            ├──► YXProtocol (library)
SwiftReceiver (executable) ─┘
YXProtocolTests (test) ─────────► YXProtocol (library)
```

### Module Structure

```
Sources/YXProtocol/
├── YXProtocol.swift         # Public API facade
├── Primitives/
│   ├── GUIDFactory.swift    # 6-byte GUID generation
│   └── DataCrypto.swift     # HMAC-SHA256, AES-256-GCM
└── Transport/
    ├── Packet.swift         # Packet struct + serialization
    ├── PacketBuilder.swift  # Build + parse packets
    └── UDPSocket.swift      # NWConnection/NWListener wrapper
```

## Traceability

**Implements**:
- `protocol/specs/technical/yx-protocol-spec.md` (full protocol)
- `protocol/specs/architecture/ybs-decisions.md` D01 (UDP), D02 (HMAC), D04 (GUID)

## Version History

### 0.1.0 (2026-04-11)
- Initial spec creation, documenting existing implementation decisions
