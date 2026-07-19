# YX Networking Framework - Python Implementation

**Status:** ⚡ Production-Ready Port
**Version:** 1.0.0
**Python:** 3.10+

---

## Overview

A production-grade Python networking framework ported from the Swift YX implementation, featuring:

- **Modern Async I/O:** 100% asyncio-based architecture
- **Type Safety:** Python 3.10+ type hints throughout
- **Security:** HMAC-SHA256 + AES-GCM encryption + rate limiting
- **Reliability:** Graceful shutdown, memory leak prevention
- **Configuration:** Fully externalized settings
- **Protocol Parity:** 100% compatible with Swift version

---

## Quick Start

### Installation

```bash
# Install dependencies
pip install -r requirements.txt

# Or install as package
pip install -e .
```

### Usage

```python
import asyncio
from yx.primitives.guid import GUIDFactory
from yx.primitives.data_crypto import generate_key
from yx.application.yx_coordinator import YXCoordinator
from yx.application.configuration import YXConfiguration

async def main():
    # Generate GUID and key
    guid = GUIDFactory.generate()
    key = generate_key()

    # Create configuration
    config = YXConfiguration.default()
    config.network.udp_port = 8888

    # Initialize coordinator
    coordinator = YXCoordinator(guid, key, config)

    # Start
    await coordinator.start()

    # Send a message
    await coordinator.send_hello("Python", "192.168.1.100", 8888)

    # Run for a while
    await asyncio.sleep(10)

    # Clean shutdown
    await coordinator.stop()

asyncio.run(main())
```

---

## CLI Usage

The yxCLI provides command-line access to YX functionality:

```bash
# Basic usage - listen on default port 9999
python -m yxCLI

# Specify port
python -m yxCLI --port 9998

# Send to peers
python -m yxCLI --port 9998 --peers localhost:9999

# Test binary protocol with compression and encryption
python -m yxCLI --port 9998 --peers localhost:9999 --proto-opts 0x03

# Auto-shutdown after 10 seconds
python -m yxCLI --port 9998 --peers localhost:9999 --shutdown-after 10
```

### CLI Arguments

- `--port <number>` - UDP listen port (default: 9999)
- `--peers <host:port,...>` - Comma-separated list of peers to send packets to
- `--proto-opts <0x00-0x03>` - Binary protocol options:
  - `0x00` = Plaintext, Uncompressed
  - `0x01` = Plaintext, Compressed
  - `0x02` = Encrypted, Uncompressed
  - `0x03` = Encrypted, Compressed
- `--shutdown-after <seconds>` - Auto-shutdown after N seconds

---

## Architecture

```
yx (Package)
  ├─ primitives/     - Foundation (GUID, crypto, compression, chunking)
  ├─ transport/      - Networking (UDP, packets, protocols, security)
  ├─ rpc/            - JSON-RPC 2.0 dispatcher
  └─ application/    - YXCoordinator, configuration
```

### Key Components

- **YXCoordinator:** Main entry point, orchestrates all subsystems
- **UDPTransport:** Async UDP with packet parsing and security
- **ProtocolRouter:** Routes packets by protocol ID
- **BinaryProtocol:** Protocol 1 with chunking/compression/encryption
- **TextProtocol:** Protocol 0 for JSON-RPC messages
- **RateLimiter:** Sliding window DoS protection
- **KeyStore:** Per-peer symmetric key management

---

## Features

### Protocols
✅ Protocol 0: Text/JSON-RPC messages
✅ Protocol 1: Binary/chunked with 4 modes (plaintext/encrypted × uncompressed/compressed)
✅ JSON-RPC 2.0 compliant dispatch
✅ Automatic message reassembly

### Security
✅ HMAC-SHA256 packet integrity (16-byte truncated)
✅ AES-GCM encryption
✅ Per-peer key management
✅ Rate limiting (default: 100 req/min per peer)
✅ Protocol ID validation

### Reliability
✅ Graceful shutdown
✅ Memory leak prevention (60s buffer timeout)
✅ Asyncio-based concurrency
✅ Comprehensive error handling

---

## Configuration

### Default Settings
```python
config = YXConfiguration.default()
# Network: UDP 9999, 4096 buffer, process own packets
# Protocol: 1024 chunk, 60s timeout
# Security: HMAC on, encryption on, 100 req/min
```

### Custom Settings
```python
config = YXConfiguration()

# Adjust network
config.network.udp_port = 7777
config.network.max_packet_size = 8192

# Adjust security
config.security.max_requests_per_window = 50
config.security.rate_limit_window = 30.0

# Adjust protocol
config.protocol.chunk_size = 2048
config.protocol.buffer_timeout = 120.0
```

---

## Testing

### Unit Tests
```bash
pytest tests/ -v
```

### P2P Testing

Run multiple instances for P2P mesh testing:

**Terminal 1 (Hub on 9999):**
```bash
python -m yxCLI --port 9999
```

**Terminal 2 (Sender on 9998):**
```bash
python -m yxCLI --port 9998 --peers localhost:9999 --shutdown-after 10
```

**Terminal 3 (Binary protocol test with compression+encryption):**
```bash
python -m yxCLI --port 9997 --peers localhost:9999 --proto-opts 0x03 --shutdown-after 10
```

---

## Protocol Specification

### UDP Packet Format

```
┌────────────────┬──────────────┬──────────────────────────────────┐
│  HMAC (16B)    │  GUID (6B)   │  Payload (variable)              │
└────────────────┴──────────────┴──────────────────────────────────┘
   0          16  17         22  23                              ...
```

**Minimum packet size:** 22 bytes

### Protocol Detection
- **First payload byte < 32 (0x00-0x1F):** Binary protocol
- **First payload byte ≥ 32 (0x20+):** Text protocol (JSON)

### Binary Protocol (Protocol 1)

**Header Format:**
```
[protoID(1)] + [protoOpts(1)] + [msgID(8)] + [chunkIndex(4)] + [totalChunks(4)] + [data]
```

**protoOpts flags:**
- Bit 0 (0x01): Compression enabled
- Bit 1 (0x02): Encryption enabled

---

## File Structure

```
src/python/
├── yx/
│   ├── primitives/
│   │   ├── guid.py                  # 6-byte GUID generation
│   │   ├── data_crypto.py           # HMAC, AES-GCM
│   │   ├── data_compression.py      # zlib compression
│   │   ├── data_chunking.py         # Chunk/unchunk data
│   │   ├── data_hex.py              # Hex utilities
│   │   ├── json_utils.py            # JSON helpers
│   │   ├── logger.py                # Emoji-based logging
│   │   └── operation_result.py      # Result type
│   ├── transport/
│   │   ├── packet.py                # Packet data structure
│   │   ├── packet_builder.py        # Build/parse packets
│   │   ├── protocol_router.py       # Route by protocol ID
│   │   ├── text_protocol.py         # Protocol 0 handler
│   │   ├── binary_protocol.py       # Protocol 1 handler
│   │   ├── udp_transport.py         # Async UDP transport
│   │   ├── rate_limiter.py          # Rate limiting
│   │   └── key_store.py             # Key management
│   ├── rpc/
│   │   └── dispatcher.py            # JSON-RPC 2.0
│   └── application/
│       ├── configuration.py         # YXConfiguration
│       └── yx_coordinator.py        # Main coordinator
├── yxCLI/
│   ├── __init__.py
│   └── __main__.py                  # CLI entry point
├── tests/
│   ├── test_primitives/
│   ├── test_transport/
│   └── test_integration/
├── requirements.txt
├── pyproject.toml
└── README.md
```

---

## Dependencies

- **cryptography** (>=41.0.0) - HMAC, AES-GCM, key generation
- **pytest** (>=7.4.0) - Testing framework
- **pytest-asyncio** (>=0.21.0) - Async test support

---

## Differences from Swift Version

1. **Async Model:** Uses asyncio instead of Swift actors
2. **Type System:** Python type hints instead of Swift's strong typing
3. **Error Handling:** Mix of exceptions and Result pattern
4. **Logging:** Similar emoji-based logging to Swift

---

## Development

### Install for Development
```bash
pip install -e ".[dev]"
```

### Run Tests
```bash
pytest tests/ -v --cov=yx
```

### Type Checking
```bash
mypy yx/
```

---

## Compatibility

This Python implementation is **100% wire-compatible** with the Swift YX version:
- Same packet format (HMAC + GUID + Payload)
- Same protocol IDs (0 = text, 1 = binary)
- Same protoOpts flags (0x00-0x03)
- Same HMAC computation (truncated SHA256)
- Same encryption (AES-GCM)
- Same compression (zlib)

Python and Swift instances can communicate seamlessly in a P2P mesh network.

---

## License

MIT

---

## Credits

Ported from the Swift YX Networking Framework v1.0.0
Original author: YX Framework Team
Python port: 2025
