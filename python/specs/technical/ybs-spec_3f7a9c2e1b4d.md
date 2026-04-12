---
name: Python Implementation Design
description: Python-specific module structure, dependency choices, asyncio model, and design decisions for the YX protocol implementation
type: technical
guid: 3f7a9c2e1b4d
version: 0.1.0
status: Implemented
last_updated: 2026-04-11
---

# Specification: Python Implementation Design

**GUID**: `3f7a9c2e1b4d`
**Version**: 0.1.0
**Status**: Implemented
**Last Updated**: 2026-04-11

## Overview

This spec captures design decisions specific to the Python implementation of the
YX protocol. It records the *why* behind Python-specific choices so that
implementers understand what is intentional vs. incidental.

The protocol requirements are in `../../../protocol/specs/`. This spec only
covers what is Python-specific.

## Goals and Non-Goals

### Goals

- Document the dependency selection rationale
- Record the asyncio design model
- Define the module and package structure
- Specify Python version constraints

### Non-Goals

- Does not define the wire format (see `protocol/specs/technical/yx-protocol-spec.md`)
- Does not define test coverage requirements (see `python/specs/testing/`)
- Does not prescribe Swift, Rust, or other implementations

## Dependencies

### Required

- `cryptography` ≥41.0.0 — HMAC-SHA256, AES-256-GCM
- `pytest` ≥7.4.0 — test framework
- `pytest-asyncio` ≥0.21.0 — async test support
- `pytest-cov` ≥4.1.0 — coverage reporting

### Why `cryptography` and not alternatives

| Option | Rejected Reason |
|---|---|
| `hashlib` (stdlib) | No constant-time HMAC comparison |
| `PyCryptodome` | Requires compile, less pythonic API |
| `pyca/cryptography` (chosen) | OpenSSL-backed, constant-time, well-audited, pip-installable |

## Requirements

### Functional Requirements

**FR-1**: Module Structure
- **Description**: Source code must live in `src/yx/primitives/` and `src/yx/transport/`
- **Priority**: High
- **Acceptance Criteria**:
  - [ ] `src/yx/primitives/` contains pure computation modules (no I/O)
  - [ ] `src/yx/transport/` contains packet handling and socket I/O
  - [ ] No circular imports between `primitives` and `transport`

**FR-2**: Async UDP Model
- **Description**: UDP send and receive operations use `asyncio`
- **Priority**: High
- **Acceptance Criteria**:
  - [ ] `UDPSocket` exposes `async def send_packet(...)` and `async def receive_packet(...)`
  - [ ] No blocking socket calls on the event loop thread
  - [ ] `asyncio.get_event_loop().run_in_executor()` used for blocking ops if needed

**FR-3**: Dataclass-Based Packet
- **Description**: The `Packet` type is a Python `dataclass`
- **Priority**: Medium
- **Acceptance Criteria**:
  - [ ] `@dataclass` decorator applied to `Packet`
  - [ ] `hmac: bytes`, `guid: bytes`, `payload: bytes` fields
  - [ ] `__post_init__` validates field lengths

**FR-4**: Constant-Time HMAC Comparison
- **Description**: HMAC verification uses constant-time comparison
- **Priority**: Critical
- **Acceptance Criteria**:
  - [ ] `hmac.compare_digest()` (or `cryptography` equivalent) used for all HMAC comparisons
  - [ ] Standard `==` never used to compare HMAC values

### Non-Functional Requirements

**NFR-1**: Python Version
- **Description**: Implementation runs on Python 3.10+
- **Metric**: `python --version`
- **Target**: 3.10 ≤ version

**NFR-2**: Zero Native Extensions
- **Description**: All dependencies install via pip without compilation
- **Metric**: `pip install -e .[dev]` succeeds on a clean machine
- **Target**: No build errors on macOS, Linux, Windows

**NFR-3**: Import Performance
- **Description**: `import yx` completes quickly
- **Metric**: Time to `import yx`
- **Target**: <100ms

## Architecture

### Module Dependency Graph

```
tests/
├── unit/
└── integration/
    
src/yx/
├── __init__.py
├── primitives/
│   ├── __init__.py
│   ├── guid_factory.py     # GUIDFactory — no external deps
│   └── data_crypto.py      # DataCrypto — depends on `cryptography`
└── transport/
    ├── __init__.py
    ├── packet.py           # Packet dataclass — no external deps
    ├── packet_builder.py   # PacketBuilder — depends on primitives
    └── udp_socket.py       # UDPSocket — depends on asyncio, packet_builder
```

### Data Flow

1. `GUIDFactory.generate()` → 6-byte `bytes`
2. `DataCrypto.compute_hmac(key, guid, payload)` → 16-byte `bytes`
3. `Packet(hmac, guid, payload)` → dataclass instance
4. `PacketBuilder.serialize(packet)` → raw `bytes`
5. `UDPSocket.send_packet(...)` → UDP datagram sent
6. `UDPSocket.receive_packet(...)` → raw `bytes` received
7. `PacketBuilder.parse_and_validate(raw, key)` → `Packet` or raises

## Traceability

**Implements**:
- `protocol/specs/technical/yx-protocol-spec.md` (full protocol)
- `protocol/specs/architecture/ybs-decisions.md` D05 (Python as reference)

## Version History

### 0.1.0 (2026-04-11)
- Initial spec creation, documenting existing implementation decisions
