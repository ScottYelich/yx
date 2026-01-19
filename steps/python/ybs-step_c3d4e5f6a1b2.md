# Step 3: Packet Data Structure

**Version**: 0.1.0

## Overview

Implement the core Packet dataclass that represents a YX protocol packet with HMAC, GUID, and payload fields. This provides the in-memory representation of packets.

## Step Objectives

1. Create Packet dataclass with three fields (hmac, guid, payload)
2. Implement serialization (to bytes)
3. Implement deserialization (from bytes)
4. Create comprehensive unit tests
5. Achieve 100% code coverage

## Prerequisites

- Step 2 completed (GUID Factory implemented)
- Python dataclasses available

## Traceability

**Implements**: specs/technical/yx-protocol-spec.md § Wire Format (HMAC + GUID + Payload)
**References**: specs/testing/testing-strategy.md § Category 1: Unit Tests

## Instructions

### 1. Create Packet Module

Create `src/yx/transport/packet.py`:

```python
"""
Packet Data Structure - In-memory representation of YX packets.

Implements: specs/technical/yx-protocol-spec.md § Wire Format
"""

from dataclasses import dataclass
from typing import Optional


@dataclass
class Packet:
    """
    YX Protocol Packet.

    Wire format:
        HMAC (16 bytes) + GUID (6 bytes) + Payload (variable)

    Minimum packet size: 22 bytes (16 + 6 + 0)
    """

    hmac: bytes      # 16 bytes
    guid: bytes      # 6 bytes
    payload: bytes   # Variable length

    def __post_init__(self):
        """Validate packet fields."""
        if not isinstance(self.hmac, bytes):
            raise TypeError(f"hmac must be bytes, got {type(self.hmac)}")
        if not isinstance(self.guid, bytes):
            raise TypeError(f"guid must be bytes, got {type(self.guid)}")
        if not isinstance(self.payload, bytes):
            raise TypeError(f"payload must be bytes, got {type(self.payload)}")

        if len(self.hmac) != 16:
            raise ValueError(f"hmac must be 16 bytes, got {len(self.hmac)}")
        if len(self.guid) != 6:
            raise ValueError(f"guid must be 6 bytes, got {len(self.guid)}")

    def to_bytes(self) -> bytes:
        """
        Serialize packet to wire format.

        Returns:
            bytes: HMAC(16) + GUID(6) + Payload(N)

        Example:
            >>> packet = Packet(b'\\x00'*16, b'\\x01'*6, b'test')
            >>> data = packet.to_bytes()
            >>> len(data)
            26
        """
        return self.hmac + self.guid + self.payload

    @classmethod
    def from_bytes(cls, data: bytes) -> Optional["Packet"]:
        """
        Deserialize packet from wire format.

        Args:
            data: Raw packet bytes (minimum 22 bytes)

        Returns:
            Packet if valid, None if invalid

        Example:
            >>> data = b'\\x00'*16 + b'\\x01'*6 + b'test'
            >>> packet = Packet.from_bytes(data)
            >>> packet.payload
            b'test'
        """
        if len(data) < 22:
            return None

        try:
            hmac = data[0:16]
            guid = data[16:22]
            payload = data[22:]
            return cls(hmac=hmac, guid=guid, payload=payload)
        except (TypeError, ValueError):
            return None

    def __len__(self) -> int:
        """Return total packet size in bytes."""
        return 16 + 6 + len(self.payload)

    def __repr__(self) -> str:
        """Return string representation."""
        return (
            f"Packet(hmac={self.hmac.hex()[:8]}..., "
            f"guid={self.guid.hex()}, "
            f"payload={len(self.payload)}B)"
        )
```

### 2. Update Package __init__.py

Update `src/yx/transport/__init__.py`:

```python
"""
YX Transport Layer - UDP packet handling.

Implements: specs/technical/yx-protocol-spec.md § Transport Layer
"""

from .packet import Packet

__all__ = ["Packet"]
```

### 3. Create Unit Tests

Create `tests/unit/test_packet.py`:

```python
"""
Unit tests for Packet data structure.

Implements: specs/testing/testing-strategy.md § Category 1: Unit Tests
"""

import pytest
from yx.transport import Packet


class TestPacketCreation:
    """Test Packet creation and validation."""

    def test_create_valid_packet(self):
        """Test creating a valid packet."""
        hmac = b'\x00' * 16
        guid = b'\x01' * 6
        payload = b'test payload'

        packet = Packet(hmac=hmac, guid=guid, payload=payload)

        assert packet.hmac == hmac
        assert packet.guid == guid
        assert packet.payload == payload

    def test_create_packet_empty_payload(self):
        """Test creating packet with empty payload."""
        hmac = b'\x00' * 16
        guid = b'\x01' * 6
        payload = b''

        packet = Packet(hmac=hmac, guid=guid, payload=payload)

        assert packet.payload == b''
        assert len(packet) == 22  # Minimum size

    def test_hmac_wrong_length_raises_error(self):
        """Test that wrong HMAC length raises ValueError."""
        with pytest.raises(ValueError, match="hmac must be 16 bytes"):
            Packet(hmac=b'\x00' * 15, guid=b'\x01' * 6, payload=b'')

    def test_guid_wrong_length_raises_error(self):
        """Test that wrong GUID length raises ValueError."""
        with pytest.raises(ValueError, match="guid must be 6 bytes"):
            Packet(hmac=b'\x00' * 16, guid=b'\x01' * 5, payload=b'')

    def test_hmac_wrong_type_raises_error(self):
        """Test that non-bytes HMAC raises TypeError."""
        with pytest.raises(TypeError, match="hmac must be bytes"):
            Packet(hmac="not bytes", guid=b'\x01' * 6, payload=b'')

    def test_guid_wrong_type_raises_error(self):
        """Test that non-bytes GUID raises TypeError."""
        with pytest.raises(TypeError, match="guid must be bytes"):
            Packet(hmac=b'\x00' * 16, guid="not bytes", payload=b'')

    def test_payload_wrong_type_raises_error(self):
        """Test that non-bytes payload raises TypeError."""
        with pytest.raises(TypeError, match="payload must be bytes"):
            Packet(hmac=b'\x00' * 16, guid=b'\x01' * 6, payload="not bytes")


class TestPacketSerialization:
    """Test Packet serialization (to_bytes)."""

    def test_to_bytes_minimal_packet(self):
        """Test serializing minimal packet (no payload)."""
        hmac = b'\xaa' * 16
        guid = b'\xbb' * 6
        payload = b''

        packet = Packet(hmac=hmac, guid=guid, payload=payload)
        data = packet.to_bytes()

        assert len(data) == 22
        assert data[0:16] == hmac
        assert data[16:22] == guid
        assert data[22:] == b''

    def test_to_bytes_with_payload(self):
        """Test serializing packet with payload."""
        hmac = b'\x01' * 16
        guid = b'\x02' * 6
        payload = b'test payload'

        packet = Packet(hmac=hmac, guid=guid, payload=payload)
        data = packet.to_bytes()

        assert len(data) == 22 + len(payload)
        assert data[0:16] == hmac
        assert data[16:22] == guid
        assert data[22:] == payload

    def test_to_bytes_large_payload(self):
        """Test serializing packet with large payload."""
        hmac = b'\xff' * 16
        guid = b'\xee' * 6
        payload = b'x' * 10000

        packet = Packet(hmac=hmac, guid=guid, payload=payload)
        data = packet.to_bytes()

        assert len(data) == 10022
        assert data[22:] == payload


class TestPacketDeserialization:
    """Test Packet deserialization (from_bytes)."""

    def test_from_bytes_minimal_packet(self):
        """Test deserializing minimal packet."""
        data = b'\xaa' * 16 + b'\xbb' * 6

        packet = Packet.from_bytes(data)

        assert packet is not None
        assert packet.hmac == b'\xaa' * 16
        assert packet.guid == b'\xbb' * 6
        assert packet.payload == b''

    def test_from_bytes_with_payload(self):
        """Test deserializing packet with payload."""
        data = b'\x01' * 16 + b'\x02' * 6 + b'test payload'

        packet = Packet.from_bytes(data)

        assert packet is not None
        assert packet.hmac == b'\x01' * 16
        assert packet.guid == b'\x02' * 6
        assert packet.payload == b'test payload'

    def test_from_bytes_too_short(self):
        """Test that packet shorter than 22 bytes returns None."""
        data = b'\x00' * 21  # One byte short

        packet = Packet.from_bytes(data)

        assert packet is None

    def test_from_bytes_empty(self):
        """Test that empty data returns None."""
        packet = Packet.from_bytes(b'')
        assert packet is None

    def test_from_bytes_exact_minimum(self):
        """Test deserializing exactly 22 bytes."""
        data = b'\x00' * 22

        packet = Packet.from_bytes(data)

        assert packet is not None
        assert len(packet.payload) == 0


class TestPacketRoundtrip:
    """Test serialization/deserialization roundtrip."""

    def test_roundtrip_minimal(self):
        """Test roundtrip with minimal packet."""
        original = Packet(hmac=b'\xaa' * 16, guid=b'\xbb' * 6, payload=b'')
        data = original.to_bytes()
        restored = Packet.from_bytes(data)

        assert restored is not None
        assert restored.hmac == original.hmac
        assert restored.guid == original.guid
        assert restored.payload == original.payload

    def test_roundtrip_with_payload(self):
        """Test roundtrip with payload."""
        original = Packet(
            hmac=b'\x01' * 16,
            guid=b'\x02' * 6,
            payload=b'test payload data'
        )
        data = original.to_bytes()
        restored = Packet.from_bytes(data)

        assert restored is not None
        assert restored.hmac == original.hmac
        assert restored.guid == original.guid
        assert restored.payload == original.payload

    def test_roundtrip_large_payload(self):
        """Test roundtrip with large payload."""
        original = Packet(
            hmac=b'\xff' * 16,
            guid=b'\xee' * 6,
            payload=b'X' * 5000
        )
        data = original.to_bytes()
        restored = Packet.from_bytes(data)

        assert restored is not None
        assert restored.hmac == original.hmac
        assert restored.guid == original.guid
        assert restored.payload == original.payload


class TestPacketUtilities:
    """Test utility methods."""

    def test_len_minimal_packet(self):
        """Test __len__ for minimal packet."""
        packet = Packet(hmac=b'\x00' * 16, guid=b'\x01' * 6, payload=b'')
        assert len(packet) == 22

    def test_len_with_payload(self):
        """Test __len__ with payload."""
        packet = Packet(hmac=b'\x00' * 16, guid=b'\x01' * 6, payload=b'test')
        assert len(packet) == 26

    def test_repr(self):
        """Test __repr__ output."""
        packet = Packet(hmac=b'\xaa' * 16, guid=b'\xbb' * 6, payload=b'test')
        repr_str = repr(packet)
        assert 'Packet' in repr_str
        assert 'hmac=' in repr_str
        assert 'guid=' in repr_str
        assert 'payload=' in repr_str
        assert 'bbbbbbbbbbbb' in repr_str  # GUID in hex
        assert '4B' in repr_str  # Payload size
```

### 4. Run Tests

```bash
pytest tests/unit/test_packet.py -v
```

### 5. Check Code Coverage

```bash
pytest tests/unit/test_packet.py --cov=src/yx/transport/packet --cov-report=term-missing
```

**Expected**: 100% coverage

## Verification

**This step is complete when:**

- [ ] `src/yx/transport/packet.py` exists with Packet dataclass
- [ ] `tests/unit/test_packet.py` exists with comprehensive tests
- [ ] All tests pass
- [ ] Code coverage ≥ 100%
- [ ] Packet can be imported and used
- [ ] Serialization/deserialization roundtrip works

**Verification Commands:**

```bash
# Run tests
pytest tests/unit/test_packet.py -v

# Check coverage
pytest tests/unit/test_packet.py --cov=src/yx/transport/packet --cov-report=term-missing

# Verify import and basic usage
python3 -c "
from yx.transport import Packet
packet = Packet(hmac=b'\\x00'*16, guid=b'\\x01'*6, payload=b'test')
assert len(packet) == 26
data = packet.to_bytes()
assert len(data) == 26
restored = Packet.from_bytes(data)
assert restored.payload == b'test'
print('✓ Packet creation, serialization, and deserialization verified')
"
```

**Expected Output:**
```
[all tests pass with 100% coverage]
✓ Packet creation, serialization, and deserialization verified
```

**Retry Policy:**
- Maximum 3 attempts
- If tests fail: Fix implementation, retry
- If coverage < 100%: Add missing tests
- If 3 failures: STOP and report

## Notes

- Packet is a simple dataclass - no logic beyond validation
- Validation ensures packet structure integrity
- Serialization is simple concatenation: HMAC + GUID + Payload
- Deserialization uses byte slicing
- This establishes the in-memory packet representation for all subsequent steps
