# Step 5: Packet Builder Implementation

**Version**: 0.1.0

## Overview

Implement the PacketBuilder that constructs complete YX packets by computing HMAC over GUID + Payload and assembling all components.

## Step Objectives

1. Implement packet building (GUID + Payload → complete Packet with HMAC)
2. Implement direct serialization (build and serialize in one step)
3. Create comprehensive unit tests
4. Achieve 100% code coverage

## Prerequisites

- Step 4 completed (HMAC computation implemented)
- All previous components available (GUID, Packet, HMAC)

## Traceability

**Implements**: specs/technical/yx-protocol-spec.md § Packet Building
**References**: specs/testing/testing-strategy.md § Category 1: Unit Tests (Protocol Layer)

## Instructions

### 1. Create Packet Builder Module

Create `src/yx/transport/packet_builder.py`:

```python
"""
Packet Builder - Construct YX packets with HMAC.

Implements: specs/technical/yx-protocol-spec.md § Packet Building/Parsing Logic
"""

from typing import Optional
from .packet import Packet
from ..primitives import GUIDFactory, compute_packet_hmac


class PacketBuilder:
    """Build YX protocol packets with HMAC computation."""

    @staticmethod
    def build_packet(guid: bytes, payload: bytes, key: bytes) -> Packet:
        """
        Build a complete YX packet with HMAC.

        Args:
            guid: Sender GUID (will be padded to 6 bytes)
            payload: Packet payload
            key: 32-byte symmetric key

        Returns:
            Packet: Complete packet with HMAC

        Example:
            >>> key = b'\\x00' * 32
            >>> guid = b'\\x01' * 6
            >>> payload = b'test'
            >>> packet = PacketBuilder.build_packet(guid, payload, key)
            >>> len(packet.hmac)
            16
        """
        # Pad GUID to exactly 6 bytes
        padded_guid = GUIDFactory.pad_guid(guid)

        # Compute HMAC over GUID + Payload
        hmac_value = compute_packet_hmac(padded_guid, payload, key)

        # Create and return packet
        return Packet(hmac=hmac_value, guid=padded_guid, payload=payload)

    @staticmethod
    def build_and_serialize(guid: bytes, payload: bytes, key: bytes) -> bytes:
        """
        Build packet and serialize to wire format in one step.

        Args:
            guid: Sender GUID
            payload: Packet payload
            key: 32-byte symmetric key

        Returns:
            bytes: Serialized packet (HMAC + GUID + Payload)

        Example:
            >>> key = b'\\x00' * 32
            >>> data = PacketBuilder.build_and_serialize(b'\\x01'*6, b'test', key)
            >>> len(data)
            26
        """
        packet = PacketBuilder.build_packet(guid, payload, key)
        return packet.to_bytes()
```

### 2. Update Package __init__.py

Update `src/yx/transport/__init__.py`:

```python
"""
YX Transport Layer - UDP packet handling.

Implements: specs/technical/yx-protocol-spec.md § Transport Layer
"""

from .packet import Packet
from .packet_builder import PacketBuilder

__all__ = ["Packet", "PacketBuilder"]
```

### 3. Create Unit Tests

Create `tests/unit/test_packet_builder.py`:

```python
"""
Unit tests for Packet Builder.

Implements: specs/testing/testing-strategy.md § Category 1: Unit Tests
"""

import pytest
from yx.transport import Packet, PacketBuilder
from yx.primitives import validate_packet_hmac


class TestBuildPacket:
    """Test packet building with HMAC computation."""

    def test_build_packet_basic(self):
        """Test building a basic packet."""
        key = b'\x00' * 32
        guid = b'\x01' * 6
        payload = b'test payload'

        packet = PacketBuilder.build_packet(guid, payload, key)

        assert isinstance(packet, Packet)
        assert packet.guid == guid
        assert packet.payload == payload
        assert len(packet.hmac) == 16

    def test_build_packet_hmac_valid(self):
        """Test that built packet has valid HMAC."""
        key = b'\x00' * 32
        guid = b'\x01' * 6
        payload = b'test'

        packet = PacketBuilder.build_packet(guid, payload, key)

        # Verify HMAC is valid
        is_valid = validate_packet_hmac(packet.guid, packet.payload, key, packet.hmac)
        assert is_valid is True

    def test_build_packet_pads_short_guid(self):
        """Test that short GUID is padded."""
        key = b'\x00' * 32
        guid = b'\x01\x02'  # Only 2 bytes
        payload = b'test'

        packet = PacketBuilder.build_packet(guid, payload, key)

        assert len(packet.guid) == 6
        assert packet.guid == b'\x01\x02\x00\x00\x00\x00'

    def test_build_packet_truncates_long_guid(self):
        """Test that long GUID is truncated."""
        key = b'\x00' * 32
        guid = b'\x01' * 8  # 8 bytes
        payload = b'test'

        packet = PacketBuilder.build_packet(guid, payload, key)

        assert len(packet.guid) == 6
        assert packet.guid == b'\x01' * 6

    def test_build_packet_empty_payload(self):
        """Test building packet with empty payload."""
        key = b'\x00' * 32
        guid = b'\x01' * 6
        payload = b''

        packet = PacketBuilder.build_packet(guid, payload, key)

        assert packet.payload == b''
        assert len(packet) == 22  # Minimum size

    def test_build_packet_different_guids_different_hmac(self):
        """Test that different GUIDs produce different HMACs."""
        key = b'\x00' * 32
        payload = b'test'

        packet1 = PacketBuilder.build_packet(b'\x01' * 6, payload, key)
        packet2 = PacketBuilder.build_packet(b'\x02' * 6, payload, key)

        assert packet1.hmac != packet2.hmac

    def test_build_packet_different_payloads_different_hmac(self):
        """Test that different payloads produce different HMACs."""
        key = b'\x00' * 32
        guid = b'\x01' * 6

        packet1 = PacketBuilder.build_packet(guid, b'payload1', key)
        packet2 = PacketBuilder.build_packet(guid, b'payload2', key)

        assert packet1.hmac != packet2.hmac

    def test_build_packet_different_keys_different_hmac(self):
        """Test that different keys produce different HMACs."""
        guid = b'\x01' * 6
        payload = b'test'

        packet1 = PacketBuilder.build_packet(guid, payload, b'\x00' * 32)
        packet2 = PacketBuilder.build_packet(guid, payload, b'\xff' * 32)

        assert packet1.hmac != packet2.hmac

    def test_build_packet_deterministic(self):
        """Test that building is deterministic."""
        key = b'\x00' * 32
        guid = b'\x01' * 6
        payload = b'test'

        packet1 = PacketBuilder.build_packet(guid, payload, key)
        packet2 = PacketBuilder.build_packet(guid, payload, key)

        assert packet1.hmac == packet2.hmac
        assert packet1.guid == packet2.guid
        assert packet1.payload == packet2.payload


class TestBuildAndSerialize:
    """Test combined build and serialization."""

    def test_build_and_serialize_basic(self):
        """Test building and serializing in one step."""
        key = b'\x00' * 32
        guid = b'\x01' * 6
        payload = b'test'

        data = PacketBuilder.build_and_serialize(guid, payload, key)

        assert isinstance(data, bytes)
        assert len(data) == 26  # 16 + 6 + 4

    def test_build_and_serialize_matches_separate_steps(self):
        """Test that combined method matches separate build + serialize."""
        key = b'\x00' * 32
        guid = b'\x01' * 6
        payload = b'test'

        # Combined method
        data1 = PacketBuilder.build_and_serialize(guid, payload, key)

        # Separate steps
        packet = PacketBuilder.build_packet(guid, payload, key)
        data2 = packet.to_bytes()

        assert data1 == data2

    def test_build_and_serialize_can_be_parsed(self):
        """Test that serialized data can be parsed back."""
        key = b'\x00' * 32
        guid = b'\x01' * 6
        payload = b'test payload'

        data = PacketBuilder.build_and_serialize(guid, payload, key)
        packet = Packet.from_bytes(data)

        assert packet is not None
        assert packet.guid == guid
        assert packet.payload == payload

    def test_build_and_serialize_hmac_valid(self):
        """Test that serialized packet has valid HMAC."""
        key = b'\x00' * 32
        guid = b'\x01' * 6
        payload = b'test'

        data = PacketBuilder.build_and_serialize(guid, payload, key)
        packet = Packet.from_bytes(data)

        assert packet is not None
        is_valid = validate_packet_hmac(packet.guid, packet.payload, key, packet.hmac)
        assert is_valid is True


class TestPacketBuilderEdgeCases:
    """Test edge cases and boundary conditions."""

    def test_build_packet_large_payload(self):
        """Test building packet with large payload."""
        key = b'\x00' * 32
        guid = b'\x01' * 6
        payload = b'X' * 10000

        packet = PacketBuilder.build_packet(guid, payload, key)

        assert len(packet.payload) == 10000
        assert validate_packet_hmac(packet.guid, packet.payload, key, packet.hmac)

    def test_build_packet_all_zeros(self):
        """Test building packet with all-zero data."""
        key = b'\x00' * 32
        guid = b'\x00' * 6
        payload = b'\x00' * 100

        packet = PacketBuilder.build_packet(guid, payload, key)

        # HMAC should not be all zeros
        assert packet.hmac != b'\x00' * 16

    def test_build_packet_all_ones(self):
        """Test building packet with all 0xFF data."""
        key = b'\xff' * 32
        guid = b'\xff' * 6
        payload = b'\xff' * 100

        packet = PacketBuilder.build_packet(guid, payload, key)

        assert len(packet) == 122
        assert validate_packet_hmac(packet.guid, packet.payload, key, packet.hmac)
```

### 4. Run Tests

```bash
pytest tests/unit/test_packet_builder.py -v
```

### 5. Check Code Coverage

```bash
pytest tests/unit/test_packet_builder.py --cov=src/yx/transport/packet_builder --cov-report=term-missing
```

**Expected**: 100% coverage

## Verification

**This step is complete when:**

- [ ] `src/yx/transport/packet_builder.py` exists with PacketBuilder class
- [ ] `tests/unit/test_packet_builder.py` exists with comprehensive tests
- [ ] All tests pass
- [ ] Code coverage ≥ 100%
- [ ] Built packets have valid HMACs
- [ ] GUID padding/truncation works correctly

**Verification Commands:**

```bash
# Run tests
pytest tests/unit/test_packet_builder.py -v

# Check coverage
pytest tests/unit/test_packet_builder.py --cov=src/yx/transport/packet_builder --cov-report=term-missing

# Verify packet building
python3 -c "
from yx.transport import PacketBuilder
from yx.primitives import validate_packet_hmac

key = b'\\x00' * 32
guid = b'\\x01' * 6
payload = b'test payload'

packet = PacketBuilder.build_packet(guid, payload, key)
assert len(packet.hmac) == 16
assert validate_packet_hmac(packet.guid, packet.payload, key, packet.hmac)

data = PacketBuilder.build_and_serialize(guid, payload, key)
assert len(data) == 16 + 6 + len(payload)

print('✓ Packet building verified')
"
```

**Expected Output:**
```
[all tests pass with 100% coverage]
✓ Packet building verified
```

**Retry Policy:**
- Maximum 3 attempts
- If tests fail: Fix implementation, retry
- If 3 failures: STOP and report

## Notes

- PacketBuilder brings together all previous components
- HMAC is computed automatically during packet construction
- GUID padding ensures protocol compliance
- This completes the packet creation pipeline
- Next step: Packet parsing and validation
