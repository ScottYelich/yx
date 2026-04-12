# Testing Specifications — Swift System-Wide Defaults

**System**: YX Swift Implementation
**Category**: Testing
**Type**: BASE
**Version**: 0.1.0
**Last Updated**: 2026-04-11

## Test Framework

- **Framework**: `XCTest` (built into Swift Package Manager)
- **Async support**: `async throws` test methods (Swift 5.5+)
- **Coverage**: `swift test --enable-code-coverage`

## Test Organization

```
Tests/YXProtocolTests/
├── Unit/           # One file per source type: <Type>Tests.swift
└── Integration/    # End-to-end: <Feature>Tests.swift
```

## Running Tests

```bash
swift test                                         # All tests
swift test --filter YXProtocolTests.Unit           # Unit only
swift test --filter YXProtocolTests.Integration    # Integration only
swift test --enable-code-coverage                  # With coverage
```

## Coverage Thresholds

Per the protocol testing BASE spec: overall ≥80%, critical paths 100%.

## Async Test Pattern

```swift
func testSendReceive() async throws {
    let socket = try UDPSocket(port: 0)
    // ...
}
```

XCTest natively supports `async throws` test methods in Swift 5.5+.

## Deterministic Time in Tests

For replay protection and rate limiting tests, inject a clock dependency:

```swift
protocol Clock {
    var now: TimeInterval { get }
}

struct MockClock: Clock {
    var now: TimeInterval = 1000.0
}
```

Pass the mock clock to the component under test rather than calling `Date()` directly.

## Canonical Validation Tests

A separate test suite in `Integration/CanonicalValidationTests.swift` loads
test vectors from `../../canonical/test-vectors/` and validates byte-for-byte
compatibility with the Python implementation.
