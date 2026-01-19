# Step 6: Packet Parser and Validator

**Version**: 0.1.0

## Overview

Implement packet parsing that deserializes wire format and validates HMAC to ensure packet integrity.

## Step Objectives

1. Parse packets from wire format
2. Validate HMAC before accepting packets
3. Handle invalid/corrupted packets gracefully
4. Comprehensive unit tests with 100% coverage

## Prerequisites

- Step 5 completed (PacketBuilder implemented)

## Traceability

**Implements**: specs/technical/yx-protocol-spec.md § Packet Parsing/Validation
**References**: specs/testing/testing-strategy.md § Category 1: Unit Tests

## Instructions

### 1. Add Parser Methods to PacketBuilder

Update `src/yx/transport/packet_builder.py`:

```python
# Add to existing file

from ..primitives import validate_packet_hmac

class PacketBuilder:
    # ... existing methods ...

    @staticmethod
    def parse_packet(data: bytes) -> Optional[Packet]:
        """
        Parse packet from wire format (no validation).

        Args:
            data: Raw packet bytes (minimum 22 bytes)

        Returns:
            Packet if parseable, None otherwise
        """
        return Packet.from_bytes(data)

    @staticmethod
    def validate_hmac(packet: Packet, key: bytes) -> bool:
        """
        Validate packet HMAC.

        Args:
            packet: Packet to validate
            key: 32-byte symmetric key

        Returns:
            bool: True if HMAC is valid
        """
        return validate_packet_hmac(packet.guid, packet.payload, key, packet.hmac)

    @staticmethod
    def parse_and_validate(data: bytes, key: bytes) -> Optional[Packet]:
        """
        Parse packet and validate HMAC.

        Args:
            data: Raw packet bytes
            key: 32-byte symmetric key

        Returns:
            Packet if valid, None if invalid/corrupted

        Example:
            >>> key = b'\\x00' * 32
            >>> data = PacketBuilder.build_and_serialize(b'\\x01'*6, b'test', key)
            >>> packet = PacketBuilder.parse_and_validate(data, key)
            >>> packet.payload
            b'test'
        """
        packet = PacketBuilder.parse_packet(data)
        if packet is None:
            return None

        if not PacketBuilder.validate_hmac(packet, key):
            return None

        return packet
```

### 2. Create Unit Tests

Create `tests/unit/test_packet_parser.py`:

```python
"""Unit tests for Packet Parser and Validator."""

import pytest
from yx.transport import PacketBuilder, Packet


class TestParsePacket:
    """Test packet parsing (no validation)."""

    def test_parse_valid_packet(self):
        """Test parsing valid packet."""
        key = b'\\x00' * 32
        data = PacketBuilder.build_and_serialize(b'\\x01'*6, b'test', key)

        packet = PacketBuilder.parse_packet(data)

        assert packet is not None
        assert packet.payload == b'test'

    def test_parse_packet_too_short(self):
        """Test that short data returns None."""
        packet = PacketBuilder.parse_packet(b'\\x00' * 21)
        assert packet is None


class TestValidateHMAC:
    """Test HMAC validation."""

    def test_validate_hmac_valid_packet(self):
        """Test validating packet with correct HMAC."""
        key = b'\\x00' * 32
        packet = PacketBuilder.build_packet(b'\\x01'*6, b'test', key)

        assert PacketBuilder.validate_hmac(packet, key) is True

    def test_validate_hmac_invalid_packet(self):
        """Test validation fails with wrong HMAC."""
        key = b'\\x00' * 32
        packet = Packet(hmac=b'\\xff'*16, guid=b'\\x01'*6, payload=b'test')

        assert PacketBuilder.validate_hmac(packet, key) is False


class TestParseAndValidate:
    """Test combined parsing and validation."""

    def test_parse_and_validate_valid_packet(self):
        """Test parsing and validating valid packet."""
        key = b'\\x00' * 32
        data = PacketBuilder.build_and_serialize(b'\\x01'*6, b'test', key)

        packet = PacketBuilder.parse_and_validate(data, key)

        assert packet is not None
        assert packet.payload == b'test'

    def test_parse_and_validate_invalid_hmac(self):
        """Test that invalid HMAC returns None."""
        key = b'\\x00' * 32
        # Build with one key, validate with another
        data = PacketBuilder.build_and_serialize(b'\\x01'*6, b'test', b'\\xff'*32)

        packet = PacketBuilder.parse_and_validate(data, key)

        assert packet is None

    def test_parse_and_validate_corrupted_data(self):
        """Test handling corrupted packet."""
        key = b'\\x00' * 32
        data = PacketBuilder.build_and_serialize(b'\\x01'*6, b'test', key)

        # Corrupt one byte in payload
        corrupted = data[:23] + bytes([(data[23] ^ 0xFF)]) + data[24:]

        packet = PacketBuilder.parse_and_validate(corrupted, key)

        assert packet is None  # HMAC validation fails

    def test_parse_and_validate_roundtrip(self):
        """Test full roundtrip: build → serialize → parse → validate."""
        key = b'\\x00' * 32
        guid = b'\\xaa' * 6
        payload = b'test payload data'

        data = PacketBuilder.build_and_serialize(guid, payload, key)
        packet = PacketBuilder.parse_and_validate(data, key)

        assert packet is not None
        assert packet.guid == guid
        assert packet.payload == payload
```

### 3. Run Tests

```bash
pytest tests/unit/test_packet_parser.py -v
pytest tests/unit/test_packet_builder.py -v  # Rerun to ensure no regressions
```

### 4. Check Coverage

```bash
pytest tests/unit/test_packet_parser.py tests/unit/test_packet_builder.py \
  --cov=src/yx/transport/packet_builder --cov-report=term-missing
```

## Verification

**This step is complete when:**

- [ ] Parser methods added to PacketBuilder
- [ ] All tests pass
- [ ] Code coverage ≥ 100%
- [ ] Invalid packets rejected
- [ ] Corrupted packets detected

**Verification Commands:**

```bash
pytest tests/unit/test_packet_parser.py tests/unit/test_packet_builder.py -v

python3 -c "
from yx.transport import PacketBuilder

key = b'\\x00' * 32
data = PacketBuilder.build_and_serialize(b'\\x01'*6, b'test', key)
packet = PacketBuilder.parse_and_validate(data, key)
assert packet is not None
assert packet.payload == b'test'

# Test invalid data
invalid = PacketBuilder.parse_and_validate(data[:20], key)
assert invalid is None

print('✓ Packet parsing and validation verified')
"
```

## Notes

- Parsing and validation are separate for flexibility
- parse_and_validate is the recommended API
- Invalid packets return None (not exceptions)
- HMAC validation prevents packet tampering
