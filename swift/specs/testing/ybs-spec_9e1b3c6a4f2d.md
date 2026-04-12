---
name: Swift Testing Strategy
description: XCTest setup, async test patterns, coverage configuration, and canonical validation for the Swift YX implementation
type: testing
guid: 9e1b3c6a4f2d
version: 0.1.0
status: Implemented
last_updated: 2026-04-11
---

# Specification: Swift Testing Strategy

**GUID**: `9e1b3c6a4f2d`
**Version**: 0.1.0
**Status**: Implemented
**Last Updated**: 2026-04-11

## Overview

Defines the testing approach for the Swift YX implementation. Covers XCTest
configuration, async test patterns, canonical validation, and coverage reporting.
Protocol-level requirements come from `protocol/specs/testing/`.

## Goals and Non-Goals

### Goals

- Define XCTest configuration for async UDP tests
- Specify canonical validation test structure
- Define coverage reporting commands
- Specify clock injection pattern for deterministic tests

### Non-Goals

- Does not define coverage thresholds (inherited from `protocol/specs/testing/_BASE.md`)
- Does not define the interop test matrix

## Requirements

### Functional Requirements

**FR-1**: XCTest Target Configuration
- **Description**: Test target is declared in `Package.swift` as a `.testTarget`
- **Priority**: High
- **Acceptance Criteria**:
  - [ ] `YXProtocolTests` test target declares dependency on `YXProtocol`
  - [ ] `swift test` discovers and runs all test cases
  - [ ] Test file naming: `<TypeName>Tests.swift`

**FR-2**: Async Test Support
- **Description**: Tests of async functions use `async throws` test methods
- **Priority**: High
- **Acceptance Criteria**:
  - [ ] All UDP tests are `async throws` XCTestCase methods
  - [ ] No `XCTestExpectation` used for async operations (use `async/await` instead)

**FR-3**: Canonical Validation Tests
- **Description**: A test suite validates Swift output against Python canonical test vectors
- **Priority**: Critical
- **Acceptance Criteria**:
  - [ ] `CanonicalValidationTests.swift` in `Tests/YXProtocolTests/Integration/`
  - [ ] Loads `canonical/test-vectors/*.json` relative to package root
  - [ ] For each test vector: computes HMAC, serializes packet, compares bytes
  - [ ] All canonical test vectors pass

**FR-4**: Security Test Coverage
- **Description**: Security-critical paths have dedicated test cases
- **Priority**: Critical
- **Acceptance Criteria**:
  - [ ] Timing: HMAC comparison uses `isValidAuthenticationCode` (constant-time)
  - [ ] Replay: duplicate GUID within TTL window is rejected
  - [ ] Rate limit: sender exceeding limit is rejected
  - [ ] Tamper: HMAC mismatch throws error

**FR-5**: Deterministic Clock for Security Tests
- **Description**: Replay and rate limit tests use injected mock clock
- **Priority**: High
- **Acceptance Criteria**:
  - [ ] `Clock` protocol defined: `var now: TimeInterval { get }`
  - [ ] `SystemClock` uses `Date().timeIntervalSince1970`
  - [ ] `MockClock` used in all time-sensitive tests
  - [ ] No calls to `Date()` directly in `ReplayWindow` or `RateLimiter`

### Non-Functional Requirements

**NFR-1**: Test Execution Speed
- **Description**: Full Swift test suite runs quickly
- **Metric**: `swift test` wall-clock time
- **Target**: <60 seconds on Apple Silicon

**NFR-2**: Test Isolation
- **Description**: Tests do not share state between test cases
- **Metric**: Tests pass in any order
- **Target**: All tests pass when run individually and in a suite

## Traceability

**Implements**:
- `protocol/specs/testing/testing-strategy.md`
- `protocol/specs/testing/interoperability-requirements.md`

## Version History

### 0.1.0 (2026-04-11)
- Initial spec creation
