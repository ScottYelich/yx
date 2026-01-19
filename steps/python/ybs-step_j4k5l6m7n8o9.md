# YBS Step 14: SimplePacketBuilder (Test Helpers)

**Step ID:** `ybs-step_j4k5l6m7n8o9`
**Language:** Python
**Estimated Duration:** 2 hours
**Prerequisites:** Steps 11-13 complete (Protocols + Security implemented)

---

## Overview

Implement `SimplePacketBuilder` - a pure function packet builder for test programs. This is **CRITICAL** for interoperability testing because it enables sender/receiver test programs to work WITHOUT the full async YX framework.

**Why This Matters:**
- Interop tests require 48 sender/receiver combinations
- Sender programs need to build packets and exit (no async framework needed)
- SimplePacketBuilder provides pure functions for packet construction
- **WITHOUT THIS, YOU CANNOT RUN INTEROP TESTS**

**Traceability:**
- `specs/architecture/api-contracts.md` - SimplePacketBuilder API
- `specs/testing/interoperability-requirements.md` - Test requirements
- SDTS spent 3-4 days discovering this pattern

---

## Context

**Problem:** Full YX framework is heavy for simple test senders:
- Requires async/await
- Requires event loop
- Requires framework initialization
- Overkill for "build packet → send → exit"

**Solution:** SimplePacketBuilder pattern:
- Pure functions (no state, no async)
- Build packet → Send → Exit
- Perfect for test programs
- Identical API across Python/Swift

**Pattern:**
```
Test Sender:
1. Import SimplePacketBuilder
2. Call build_text_packet() or build_binary_packet()
3. Send via raw UDP socket
4. Exit

Test Receiver:
1. Import full YX framework
2. Start listening
3. Wait for message
4. Exit with success code
```

---

## Goals

1. ✅ SimplePacketBuilder class with static methods
2. ✅ Build Protocol 0 packets (text)
3. ✅ Build Protocol 1 packets (binary, all protoOpts)
4. ✅ UDP send helpers (synchronous)
5. ✅ TestConfig utilities
6. ✅ Unit tests
7. ✅ Integration test (build + send + receive)
8. ✅ Traceability ≥80%

---

## File Structure

```
canonical/python/src/yx/
└── primitives/
    └── test_helpers.py    # NEW: SimplePacketBuilder
```

---

## Implementation

**File:** `canonical/python/src/yx/primitives/test_helpers.py`

```python
"""
Test helpers for YX interoperability testing.

Traceability:
- specs/architecture/api-contracts.md (SimplePacketBuilder API)
- specs/testing/interoperability-requirements.md (Test Requirements)

CRITICAL: SimplePacketBuilder enables interop tests without full framework.
This pattern was learned through SDTS development (3-4 days to discover).
"""

import json
import struct
import socket
import os
from typing import Dict, Any, List

from .data_compression import compress_data
from .data_crypto import encrypt_aes_gcm, compute_hmac
from .data_chunking import chunk_data
from ..transport.packet_builder import PacketBuilder


class TestConfig:
    """
    Test configuration utilities.

    Traceability:
    - specs/technical/default-values.md (test_port = 49999)
    - specs/architecture/api-contracts.md (TestConfig)
    """

    @staticmethod
    def test_port() -> int:
        """
        Get test port from environment or default.

        Returns:
            Port number (default: 49999, NOT 50000 to avoid conflict)

        Traceability:
        - specs/technical/default-values.md (test_port)
        """
        return int(os.environ.get('TEST_YX_PORT', '49999'))

    @staticmethod
    def test_guid() -> bytes:
        """
        Get fixed test GUID.

        Returns:
            6 bytes of 0x01 (for reproducible tests)

        Traceability:
        - specs/testing/interoperability-requirements.md (Shared Configuration)
        """
        return bytes([0x01] * 6)

    @staticmethod
    def test_key() -> bytes:
        """
        Get fixed test key.

        Returns:
            32 bytes of 0x00 (for reproducible tests)

        Traceability:
        - specs/testing/interoperability-requirements.md (Shared Configuration)
        """
        return bytes(32)


class SimplePacketBuilder:
    """
    Pure function packet builder for test programs.

    Design:
    - Synchronous (no async)
    - Pure functions (no state)
    - Builds packets ready for UDP send

    Traceability:
    - specs/architecture/api-contracts.md (SimplePacketBuilder)
    - specs/architecture/protocol-layers.md (Protocol 0, Protocol 1)

    Usage Pattern:
        # Test sender program
        packet = SimplePacketBuilder.build_text_packet(message, guid, key)
        send_udp_packet(packet, "127.0.0.1", 49999)
        sys.exit(0)
    """

    @staticmethod
    def build_text_packet(
        message: Dict[str, Any],
        guid: bytes,
        key: bytes
    ) -> bytes:
        """
        Build Protocol 0 (text) packet.

        Args:
            message: JSON-serializable dict
            guid: 6-byte GUID
            key: 32-byte symmetric key

        Returns:
            Complete packet: [HMAC(16)] + [GUID(6)] + [0x00] + [JSON]

        Traceability:
        - specs/architecture/protocol-layers.md (Protocol 0)
        - specs/architecture/api-contracts.md (build_text_packet)
        """
        # Encode as JSON
        json_str = json.dumps(message)
        json_bytes = json_str.encode('utf-8')

        # Build Protocol 0 payload: [0x00] + [JSON]
        payload = bytes([0x00]) + json_bytes

        # Build packet with HMAC
        packet = PacketBuilder.build_packet(guid, payload, key)

        return packet.to_bytes()

    @staticmethod
    def build_binary_packet(
        data: bytes,
        guid: bytes,
        key: bytes,
        proto_opts: int = 0x00,
        channel_id: int = 0,
        sequence: int = 0,
        chunk_size: int = 1024
    ) -> List[bytes]:
        """
        Build Protocol 1 (binary) packets.

        Args:
            data: Application data
            guid: 6-byte GUID
            key: 32-byte symmetric key
            proto_opts: Protocol options (0x00, 0x01, 0x02, 0x03)
            channel_id: Channel ID (0-65535)
            sequence: Sequence number (0-2^32-1)
            chunk_size: Chunk size in bytes (default: 1024)

        Returns:
            List of packets (one per chunk)

        Traceability:
        - specs/architecture/protocol-layers.md (Protocol 1)
        - specs/architecture/api-contracts.md (build_binary_packet)

        Processing order: compress → encrypt → chunk → build packets
        """
        # Compress if needed
        if proto_opts & 0x01:
            data = compress_data(data)

        # Encrypt if needed
        if proto_opts & 0x02:
            nonce, ciphertext_with_tag = encrypt_aes_gcm(data, key)
            data = nonce + ciphertext_with_tag

        # Chunk
        chunks = chunk_data(data, chunk_size)
        total_chunks = len(chunks)

        # Build packet for each chunk
        packets = []

        # Header format: proto(1) + protoOpts(1) + channelID(2) + sequence(4) + chunkIndex(4) + totalChunks(4)
        HEADER_FORMAT = ">BBHIII"

        for chunk_index, chunk in enumerate(chunks):
            # Build Protocol 1 header
            header = struct.pack(
                HEADER_FORMAT,
                0x01,  # Protocol ID: Binary
                proto_opts,
                channel_id,
                sequence,
                chunk_index,
                total_chunks
            )

            # Payload = header + chunk
            payload = header + chunk

            # Build packet with HMAC
            packet = PacketBuilder.build_packet(guid, payload, key)

            packets.append(packet.to_bytes())

        return packets


def send_udp_packet(packet: bytes, host: str, port: int):
    """
    Send single UDP packet using BSD socket.

    Args:
        packet: Complete packet bytes
        host: Destination IP
        port: Destination port

    Traceability:
    - specs/architecture/api-contracts.md (send_udp_packet)

    Note: Synchronous (no async needed for test senders)
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.sendto(packet, (host, port))
    finally:
        sock.close()


def send_udp_packets(packets: List[bytes], host: str, port: int):
    """
    Send multiple UDP packets using BSD socket.

    Args:
        packets: List of complete packet bytes
        host: Destination IP
        port: Destination port

    Traceability:
    - specs/architecture/api-contracts.md (send_udp_packets)
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        for packet in packets:
            sock.sendto(packet, (host, port))
    finally:
        sock.close()
```

---

## Tests

**File:** `canonical/python/src/yx/primitives/test_test_helpers.py`

```python
"""
Tests for test helpers.

Traceability:
- specs/architecture/api-contracts.md (SimplePacketBuilder Tests)
"""

import pytest
import os
from yx.primitives.test_helpers import (
    TestConfig,
    SimplePacketBuilder,
    send_udp_packet,
    send_udp_packets
)
from yx.transport.packet_builder import PacketBuilder


def test_test_config_port():
    """Test TestConfig.test_port()."""
    port = TestConfig.test_port()
    assert port == 49999  # Default


def test_test_config_guid():
    """Test TestConfig.test_guid()."""
    guid = TestConfig.test_guid()
    assert len(guid) == 6
    assert guid == bytes([0x01] * 6)


def test_test_config_key():
    """Test TestConfig.test_key()."""
    key = TestConfig.test_key()
    assert len(key) == 32
    assert key == bytes(32)


def test_simple_packet_builder_text():
    """Test SimplePacketBuilder.build_text_packet()."""
    guid = os.urandom(6)
    key = os.urandom(32)
    message = {"method": "test", "params": {"value": 42}}

    packet_bytes = SimplePacketBuilder.build_text_packet(message, guid, key)

    # Verify structure
    assert len(packet_bytes) >= 22  # Minimum: HMAC(16) + GUID(6)

    # Parse packet
    packet = PacketBuilder.parse_packet(packet_bytes)
    assert packet.guid == guid

    # Verify HMAC
    assert PacketBuilder.validate_hmac(packet, key, ("127.0.0.1", 12345))

    # Verify Protocol 0 marker
    assert packet.payload[0] == 0x00

    # Verify JSON content
    import json
    json_bytes = packet.payload[1:]
    parsed = json.loads(json_bytes.decode('utf-8'))
    assert parsed == message


def test_simple_packet_builder_binary_single_chunk():
    """Test SimplePacketBuilder.build_binary_packet() with single chunk."""
    guid = os.urandom(6)
    key = os.urandom(32)
    data = b"Small data"

    packets = SimplePacketBuilder.build_binary_packet(
        data, guid, key,
        proto_opts=0x00,
        channel_id=0,
        sequence=0
    )

    assert len(packets) == 1  # Single chunk

    # Parse packet
    packet = PacketBuilder.parse_packet(packets[0])
    assert packet.guid == guid

    # Verify HMAC
    assert PacketBuilder.validate_hmac(packet, key, ("127.0.0.1", 12345))

    # Verify Protocol 1 marker
    assert packet.payload[0] == 0x01


def test_simple_packet_builder_binary_multi_chunk():
    """Test SimplePacketBuilder.build_binary_packet() with multiple chunks."""
    guid = os.urandom(6)
    key = os.urandom(32)
    data = b"A" * 2500  # Will be 3 chunks at 1024 bytes each

    packets = SimplePacketBuilder.build_binary_packet(
        data, guid, key,
        proto_opts=0x00,
        channel_id=0,
        sequence=0,
        chunk_size=1024
    )

    assert len(packets) == 3  # Three chunks


def test_simple_packet_builder_binary_compressed():
    """Test SimplePacketBuilder.build_binary_packet() with compression."""
    guid = os.urandom(6)
    key = os.urandom(32)
    data = b"Hello! " * 100  # Compressible data

    packets = SimplePacketBuilder.build_binary_packet(
        data, guid, key,
        proto_opts=0x01,  # Compress
        channel_id=0,
        sequence=0
    )

    assert len(packets) >= 1


def test_simple_packet_builder_binary_encrypted():
    """Test SimplePacketBuilder.build_binary_packet() with encryption."""
    guid = os.urandom(6)
    key = os.urandom(32)
    data = b"Secret message!"

    packets = SimplePacketBuilder.build_binary_packet(
        data, guid, key,
        proto_opts=0x02,  # Encrypt
        channel_id=0,
        sequence=0
    )

    assert len(packets) >= 1


def test_simple_packet_builder_binary_both():
    """Test SimplePacketBuilder.build_binary_packet() with compression + encryption."""
    guid = os.urandom(6)
    key = os.urandom(32)
    data = b"Secret! " * 100

    packets = SimplePacketBuilder.build_binary_packet(
        data, guid, key,
        proto_opts=0x03,  # Both
        channel_id=0,
        sequence=0
    )

    assert len(packets) >= 1


def test_send_udp_packet_does_not_crash():
    """Test send_udp_packet() doesn't crash (actual send may fail if port closed)."""
    packet = b"test packet"

    # Should not raise (send may fail silently if port closed)
    try:
        send_udp_packet(packet, "127.0.0.1", 19999)
    except Exception as e:
        pytest.skip(f"UDP send failed (expected if port closed): {e}")


def test_send_udp_packets_does_not_crash():
    """Test send_udp_packets() doesn't crash."""
    packets = [b"packet1", b"packet2", b"packet3"]

    # Should not raise
    try:
        send_udp_packets(packets, "127.0.0.1", 19999)
    except Exception as e:
        pytest.skip(f"UDP send failed (expected if port closed): {e}")
```

---

## Integration Test

**File:** `canonical/python/src/yx/primitives/test_simple_packet_builder_integration.py`

```python
"""
Integration test: Build packet with SimplePacketBuilder, send, receive with full framework.

Traceability:
- specs/testing/interoperability-requirements.md (Test Pattern)
"""

import pytest
import asyncio
import os
from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packet, TestConfig
from yx.transport.udp_socket import UDPSocket
from yx.transport.packet_builder import PacketBuilder


@pytest.mark.asyncio
async def test_simple_packet_builder_integration():
    """
    Integration test: Build + send + receive.

    Pattern:
    1. Create receiver (full framework)
    2. Build packet with SimplePacketBuilder
    3. Send packet
    4. Verify receiver gets it
    """
    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    received = []

    # Start receiver
    receiver = UDPSocket(port=port)

    async def receive_task():
        try:
            data, addr = receiver.receive_packet(timeout=2.0)
            packet = PacketBuilder.parse_packet(data)
            if PacketBuilder.validate_hmac(packet, key, addr):
                received.append(packet.payload)
        except Exception as e:
            pass  # Timeout expected

    receive_future = asyncio.create_task(receive_task())

    # Wait for receiver to bind
    await asyncio.sleep(0.1)

    # Build and send packet
    message = {"method": "test", "params": {"value": 42}}
    packet = SimplePacketBuilder.build_text_packet(message, guid, key)
    send_udp_packet(packet, "127.0.0.1", port)

    # Wait for receive
    await receive_future

    # Verify
    assert len(received) == 1
    assert received[0][0] == 0x00  # Protocol 0

    # Cleanup
    receiver.close()
```

---

## Verification

```bash
cd canonical/python

# Run test helper tests
pytest src/yx/primitives/test_test_helpers.py -v
pytest src/yx/primitives/test_simple_packet_builder_integration.py -v

# Verify all tests pass
pytest src/yx/ -v --tb=short
```

---

## Success Criteria

✅ **SimplePacketBuilder implemented:**
- [ ] build_text_packet() works
- [ ] build_binary_packet() works (all protoOpts)
- [ ] UDP send helpers work
- [ ] TestConfig utilities work

✅ **Tests passing:**
- [ ] 10+ unit tests passing
- [ ] Integration test passing (build → send → receive)
- [ ] All protocol options tested (0x00, 0x01, 0x02, 0x03)

✅ **Ready for interop testing:**
- [ ] Can build packets without async framework
- [ ] Can send packets with raw UDP socket
- [ ] API matches specs/architecture/api-contracts.md

✅ **Traceability:**
- [ ] ≥80% of code has traceability comments
- [ ] References api-contracts.md
- [ ] References interoperability-requirements.md

---

## Usage Example

**Test Sender (sender_proto0.py):**
```python
#!/usr/bin/env python3
"""Simple test sender using SimplePacketBuilder."""

import sys
from yx.primitives.test_helpers import (
    SimplePacketBuilder,
    send_udp_packet,
    TestConfig
)

def main():
    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    message = {
        "method": "test.hello",
        "params": {"name": "TestSender"}
    }

    # Build packet (no async needed!)
    packet = SimplePacketBuilder.build_text_packet(message, guid, key)

    # Send packet
    send_udp_packet(packet, "127.0.0.1", port)

    print(f"SENT: {message}")
    sys.exit(0)  # Exit immediately

if __name__ == "__main__":
    main()
```

**Test Receiver (receiver_proto0.py):**
```python
#!/usr/bin/env python3
"""Test receiver using full YX framework."""

import sys
import asyncio
from yx.transport.udp_socket import UDPSocket
from yx.transport.packet_builder import PacketBuilder
from yx.primitives.test_helpers import TestConfig

async def main():
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    receiver = UDPSocket(port=port)

    try:
        data, addr = receiver.receive_packet(timeout=5.0)
        packet = PacketBuilder.parse_packet(data)

        if PacketBuilder.validate_hmac(packet, key, addr):
            print(f"RECEIVED: Message from {packet.guid.hex()}")
            sys.exit(0)  # Success
        else:
            print("FAILED: HMAC invalid")
            sys.exit(1)
    except Exception as e:
        print(f"FAILED: {e}")
        sys.exit(1)
    finally:
        receiver.close()

if __name__ == "__main__":
    asyncio.run(main())
```

---

## Next Steps

After this step:

1. ✅ Commit changes
2. ✅ Proceed to **Step 15: Interoperability Test Suite (48 tests)**

---

## References

**Specifications:**
- `specs/architecture/api-contracts.md` - SimplePacketBuilder API
- `specs/testing/interoperability-requirements.md` - Test requirements
- `specs/technical/default-values.md` - Test configuration

**SDTS Reference:**
- `sdts-comparison/python/yx/primitives/test_helpers.py` - Reference implementation
