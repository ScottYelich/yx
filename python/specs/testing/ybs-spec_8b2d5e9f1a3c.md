---
name: Python Testing Strategy
description: pytest setup, async testing patterns, coverage targets, and canonical artifact generation for the Python YX implementation
type: testing
guid: 8b2d5e9f1a3c
version: 0.1.0
status: Implemented
last_updated: 2026-04-11
---

# Specification: Python Testing Strategy

**GUID**: `8b2d5e9f1a3c`
**Version**: 0.1.0
**Status**: Implemented
**Last Updated**: 2026-04-11

## Overview

Defines the testing approach for the Python YX implementation. Covers framework
configuration, test organization, coverage requirements, and canonical artifact
generation. Protocol-level testing requirements (coverage thresholds, interop
matrix) come from `protocol/specs/testing/`; this spec adds Python-specific
detail.

## Goals and Non-Goals

### Goals

- Define pytest configuration and plugin usage
- Specify how async UDP tests are structured
- Define the canonical artifact generation process
- Specify coverage reporting and thresholds

### Non-Goals

- Does not define test coverage thresholds (inherited from `protocol/specs/testing/_BASE.md`)
- Does not define the interop test matrix (see `protocol/specs/testing/interoperability-requirements.md`)

## Requirements

### Functional Requirements

**FR-1**: pytest Configuration
- **Description**: pytest is configured via `pyproject.toml`, not `pytest.ini` or `setup.cfg`
- **Priority**: High
- **Acceptance Criteria**:
  - [ ] `[tool.pytest.ini_options]` section in `pyproject.toml`
  - [ ] `testpaths = ["tests"]`
  - [ ] `asyncio_mode = "auto"`
  - [ ] `python_files`, `python_classes`, `python_functions` patterns defined

**FR-2**: Coverage Configuration
- **Description**: Coverage reports exclude non-testable lines
- **Priority**: Medium
- **Acceptance Criteria**:
  - [ ] `[tool.coverage.run]` configured with `source = ["src"]`
  - [ ] `[tool.coverage.report]` excludes `__repr__`, `raise NotImplementedError`, etc.
  - [ ] `pytest --cov=src --cov-report=term-missing` produces a clean report

**FR-3**: Canonical Artifact Generation
- **Description**: A test/script generates canonical JSON test vectors
- **Priority**: Critical
- **Acceptance Criteria**:
  - [ ] `tests/generate_canonical.py` script exists
  - [ ] Running it produces `canonical/test-vectors/` JSON files
  - [ ] Each test vector has: `name`, `guid`, `key`, `payload_hex`, `expected_hmac`, `expected_packet_hex`
  - [ ] Generated vectors pass validation by a separate read-and-verify script

**FR-4**: Security Test Coverage
- **Description**: Security-critical paths have dedicated test cases
- **Priority**: Critical
- **Acceptance Criteria**:
  - [ ] Timing attack test: verifies HMAC comparison takes constant time (or uses `compare_digest`)
  - [ ] Avalanche test: one-bit change in key/payload produces different HMAC
  - [ ] Replay test: duplicate GUID within TTL window is rejected
  - [ ] Rate limit test: sender exceeding limit is rejected

### Non-Functional Requirements

**NFR-1**: Test Speed
- **Description**: Full test suite runs quickly
- **Metric**: Wall-clock time for `pytest`
- **Target**: <30 seconds on developer hardware

**NFR-2**: No Test Dependencies on External Services
- **Description**: All tests run offline with no network dependency except
  integration tests that bind to loopback
- **Metric**: `pytest tests/unit/` succeeds with no network

## Traceability

**Implements**:
- `protocol/specs/testing/testing-strategy.md` (Python test patterns)
- `protocol/specs/testing/interoperability-requirements.md` (interop test setup)

## Version History

### 0.1.0 (2026-04-11)
- Initial spec creation
