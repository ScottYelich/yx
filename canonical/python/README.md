# YX Protocol - Python Reference Implementation

**Status:** ✅ **COMPLETE** (2026-01-18)

This directory contains the **working reference implementation** of the YX protocol in Python.

## Overview

Secure, payload-agnostic UDP-based networking protocol as specified in `../../specs/technical/yx-protocol-spec.md`

## Implementation Details

- **Language:** Python 3.10+
- **Tests:** 100 tests (all passing)
- **Coverage:** ≥94% across all modules
- **Protocol Version:** 0.1.0

## Components

### Core Modules
- `src/yx/primitives/guid_factory.py` - 6-byte GUID generation (19 tests)
- `src/yx/primitives/data_crypto.py` - HMAC-SHA256 security (27 tests)
- `src/yx/transport/packet.py` - Packet data structure (22 tests)
- `src/yx/transport/packet_builder.py` - Packet construction & parsing (24 tests)
- `src/yx/transport/udp_socket.py` - UDP transport layer (6 tests)

### Test Suite
- **Unit Tests:** 96 tests across 7 test files
- **Integration Tests:** 4 end-to-end tests
- **Security Tests:** HMAC validation, timing attack prevention, avalanche effect

## Installation

```bash
pip install -e .[dev]
```

## Running Tests

```bash
# All tests
pytest

# With coverage
pytest --cov=src --cov-report=html

# Integration tests only
pytest tests/integration/
```

## Usage Example

```python
from yx.transport import PacketBuilder, UDPSocket
from yx.primitives import GUIDFactory

# Generate GUID and key
guid = GUIDFactory.generate()
key = b'\x00' * 32  # Use secure key in production

# Build and send packet
socket = UDPSocket(port=5000)
socket.send_packet(guid=guid, payload=b'Hello YX!', key=key, dest=('localhost', 5000))

# Receive and validate packet
packet = socket.receive_packet(key=key, timeout=1.0)
if packet:
    print(f"Received: {packet.payload}")
```

## Canonical Artifacts Generated

This implementation generated canonical test vectors used for cross-language validation:
- `../../canonical/test-vectors/text-protocol-packets.json` - 3 test cases with known inputs/outputs

All future language implementations (Swift, Rust, Go, etc.) **must** pass these test vectors to ensure wire format compatibility.

## Verification

All verification criteria met:
- ✅ All 100 tests passing
- ✅ GUID generation (cryptographically secure)
- ✅ HMAC-SHA256 computation and validation
- ✅ Packet serialization/deserialization
- ✅ UDP socket configuration (broadcast mode)
- ✅ UDP send/receive operations
- ✅ End-to-end packet flows
- ✅ Invalid/corrupted packet rejection
- ✅ Large payload support (tested up to 10KB)
- ✅ Canonical test vectors generated

## Next Steps

This reference implementation is ready for:
1. Swift implementation validation (use canonical test vectors)
2. Cross-language interoperability testing
3. Production deployment (after security audit)

## Build System

Built using YBS (Yelich Build System) - see `../../steps/python/` for build instructions.

**Promoted from:** `builds/python-impl/` on 2026-01-18
