# YBS Step: SimplePacketBuilder and TestConfig

**Step ID:** `ybs-step_j4a0b1c2d3e4`
**Language:** Python
**Prerequisites:** Steps h2a-h2d, i3a-i3d complete

---

## ⚠️ CRITICAL: Do NOT use canonical/ as proof of completion

The `canonical/` directory contains reference files. **DO NOT** look at `canonical/` to confirm work is done.
Verify ONLY by:
1. File exists at `{{CONFIG:impl_src}}/primitives/test_helpers.py`
2. Tests pass when running pytest

Your target directory is `{{CONFIG:impl_src}}` (resolves to `src/yx`).

---

## ⚠️ CRITICAL API NOTES

`PacketBuilder.validate_hmac(packet, key)` — takes exactly 2 arguments. NO `addr` argument.
`PacketBuilder.build_packet(guid, payload, key)` returns a `Packet` object — call `.to_bytes()` to serialize.

---

## What This Step Builds

Create `{{CONFIG:impl_src}}/primitives/test_helpers.py` — synchronous packet builder for test programs.

---

## Implementation

**File:** `{{CONFIG:impl_src}}/primitives/test_helpers.py`

```python
"""
Test helpers for YX interoperability testing.

SimplePacketBuilder: synchronous packet builder for test senders.
Enables building and sending YX packets without the full async framework.

Traceability:
- protocol/specs/architecture/api-contracts.md (SimplePacketBuilder API)
- protocol/specs/testing/interoperability-requirements.md (Test Requirements)
"""

import json
import struct
import socket
import os
from typing import Dict, Any, List

from .data_compression import compress_data
from .data_crypto import encrypt_aes_gcm
from .data_chunking import chunk_data
from ..transport.packet_builder import PacketBuilder


class TestConfig:
    """
    Shared test configuration.

    Traceability:
    - protocol/specs/technical/default-values.md (test_port = 49999)
    - protocol/specs/testing/interoperability-requirements.md (Shared Configuration)
    """

    @staticmethod
    def test_port() -> int:
        """Test port (default: 49999, avoids conflict with 50000)."""
        return int(os.environ.get('TEST_YX_PORT', '49999'))

    @staticmethod
    def test_guid() -> bytes:
        """Fixed 6-byte test GUID (reproducible tests)."""
        return bytes([0x01] * 6)

    @staticmethod
    def test_key() -> bytes:
        """Fixed 32-byte test key (reproducible tests)."""
        return bytes(32)


class SimplePacketBuilder:
    """
    Pure function packet builder for test programs.

    No async, no state, no framework overhead.
    Build a packet, send it, exit.

    Traceability:
    - protocol/specs/architecture/api-contracts.md (SimplePacketBuilder)
    - protocol/specs/architecture/protocol-layers.md (Protocol 0, Protocol 1)
    """

    @staticmethod
    def build_text_packet(
        message: Dict[str, Any],
        guid: bytes,
        key: bytes
    ) -> bytes:
        """
        Build Protocol 0 (text/JSON) packet.

        Returns:
            Complete packet bytes: HMAC(16) + GUID(6) + [0x00] + JSON

        Traceability:
        - protocol/specs/architecture/protocol-layers.md (Protocol 0)
        """
        json_bytes = json.dumps(message).encode('utf-8')
        payload = bytes([0x00]) + json_bytes
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

        Returns:
            List of packet bytes (one per chunk)

        Processing order: compress → encrypt → chunk

        Traceability:
        - protocol/specs/architecture/protocol-layers.md (Protocol 1)
        """
        # Compress if needed
        if proto_opts & 0x01:
            data = compress_data(data)

        # Encrypt if needed
        if proto_opts & 0x02:
            nonce, ct = encrypt_aes_gcm(data, key)
            data = nonce + ct

        chunks = chunk_data(data, chunk_size)
        total = len(chunks)

        # Header: proto(1) + protoOpts(1) + channelID(2) + seq(4) + chunkIdx(4) + totalChunks(4)
        HEADER_FMT = ">BBHIII"

        packets = []
        for i, chunk in enumerate(chunks):
            header = struct.pack(HEADER_FMT, 0x01, proto_opts, channel_id, sequence, i, total)
            payload = header + chunk
            packet = PacketBuilder.build_packet(guid, payload, key)
            packets.append(packet.to_bytes())

        return packets


def send_udp_packet(packet: bytes, host: str, port: int):
    """
    Send single UDP packet synchronously.

    Traceability:
    - protocol/specs/architecture/api-contracts.md (send_udp_packet)
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.sendto(packet, (host, port))
    finally:
        sock.close()


def send_udp_packets(packets: List[bytes], host: str, port: int):
    """
    Send multiple UDP packets synchronously.

    Traceability:
    - protocol/specs/architecture/api-contracts.md (send_udp_packets)
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

**File:** `{{CONFIG:impl_src}}/primitives/test_test_helpers.py`

```python
"""Tests for test helpers (SimplePacketBuilder, TestConfig)."""

import pytest
import os
from yx.primitives.test_helpers import TestConfig, SimplePacketBuilder, send_udp_packet, send_udp_packets
from yx.transport.packet_builder import PacketBuilder


def test_config_port():
    assert TestConfig.test_port() == 49999


def test_config_guid():
    guid = TestConfig.test_guid()
    assert len(guid) == 6
    assert guid == bytes([0x01] * 6)


def test_config_key():
    key = TestConfig.test_key()
    assert len(key) == 32
    assert key == bytes(32)


def test_build_text_packet():
    guid = os.urandom(6)
    key = os.urandom(32)
    message = {"method": "test", "params": {"value": 42}}

    packet_bytes = SimplePacketBuilder.build_text_packet(message, guid, key)
    assert len(packet_bytes) >= 22

    packet = PacketBuilder.parse_packet(packet_bytes)
    assert packet is not None
    assert packet.guid == guid
    assert PacketBuilder.validate_hmac(packet, key)
    assert packet.payload[0] == 0x00

    import json
    parsed = json.loads(packet.payload[1:].decode('utf-8'))
    assert parsed == message


def test_build_binary_single_chunk():
    guid = os.urandom(6)
    key = os.urandom(32)
    data = b"Small data"

    packets = SimplePacketBuilder.build_binary_packet(data, guid, key, proto_opts=0x00)
    assert len(packets) == 1

    packet = PacketBuilder.parse_packet(packets[0])
    assert packet is not None
    assert PacketBuilder.validate_hmac(packet, key)
    assert packet.payload[0] == 0x01


def test_build_binary_multi_chunk():
    guid = os.urandom(6)
    key = os.urandom(32)
    data = b"A" * 2500

    packets = SimplePacketBuilder.build_binary_packet(
        data, guid, key, proto_opts=0x00, chunk_size=1024
    )
    assert len(packets) == 3


def test_build_binary_compressed():
    guid = os.urandom(6)
    key = os.urandom(32)
    packets = SimplePacketBuilder.build_binary_packet(
        b"Hello! " * 100, guid, key, proto_opts=0x01
    )
    assert len(packets) >= 1


def test_build_binary_encrypted():
    guid = os.urandom(6)
    key = os.urandom(32)
    packets = SimplePacketBuilder.build_binary_packet(
        b"Secret!", guid, key, proto_opts=0x02
    )
    assert len(packets) >= 1


def test_build_binary_both():
    guid = os.urandom(6)
    key = os.urandom(32)
    packets = SimplePacketBuilder.build_binary_packet(
        b"Secret! " * 100, guid, key, proto_opts=0x03
    )
    assert len(packets) >= 1
```

---

## Verification

```bash
pytest {{CONFIG:impl_src}}/primitives/test_test_helpers.py -v
```

All 8 tests must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_j4a0b1c2d3e4-DONE.txt`:

```
STEP: ybs-step_j4a0b1c2d3e4
COMPLETED: [ISO 8601 timestamp]
FILES: src/yx/primitives/test_helpers.py, test_test_helpers.py
VERIFICATION: PASSED
NEXT: ybs-step_j4b0c1d2e3f4
```

Update `BUILD_STATUS.md`: add `- [x] j4a0b1c2d3e4`.
