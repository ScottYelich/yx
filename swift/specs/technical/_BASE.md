# Technical Specifications — Swift System-Wide Defaults

**System**: YX Swift Implementation
**Category**: Technical
**Type**: BASE
**Version**: 0.1.0
**Last Updated**: 2026-04-11

## Language Version

- **Minimum**: Swift 5.9
- **Recommended**: Swift 5.10+
- Reason: parameter packs (5.9), improved `Sendable` checking (5.10)

## Package Management

- **Tool**: Swift Package Manager (`Package.swift`)
- No CocoaPods, no Carthage
- All targets declared in `Package.swift`

## Coding Standards

- `struct` preferred over `class` for data types (value semantics)
- `enum` with associated values for result types and errors
- `throws` / `try` for error handling, not optional chaining for errors
- `Sendable` conformance required for types crossing concurrency boundaries
- Property names: `lowerCamelCase`; type names: `UpperCamelCase`

## Concurrency Model

- Swift `async/await` for async operations
- `Actor` for shared mutable state (e.g., replay window store, rate limiter)
- `Task` for fire-and-forget; `TaskGroup` for structured concurrency
- No `DispatchQueue` for new code

## Cryptography

- **Framework**: `CryptoKit` (Apple-native, no third-party dependency)
- `HMAC<SHA256>` for authentication
- `AES.GCM` for encryption
- Constant-time comparison via `CryptoKit.HMAC.isValidAuthenticationCode`

## Module Structure Convention

```
Sources/YXProtocol/
├── Primitives/    # Pure computation: GUIDFactory, DataCrypto
└── Transport/     # I/O and packet: Packet, PacketBuilder, UDPSocket
```

Same layering constraint as Python: `Primitives` has no I/O.
