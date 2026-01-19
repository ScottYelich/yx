# Step 2: GUID Factory Implementation

**Version**: 0.1.0

## Overview

Implement the GUID (Globally Unique Identifier) factory that generates 6-byte identifiers for packet senders. This is the first core component of the YX protocol.

## Step Objectives

1. Implement GUID generation (6 random bytes)
2. Implement GUID padding (ensure exactly 6 bytes)
3. Create comprehensive unit tests
4. Achieve 100% code coverage for GUID factory

## Prerequisites

- Step 1 completed (Project setup complete)
- Python environment configured
- pytest available

## Traceability

**Implements**: specs/technical/yx-protocol-spec.md § Layer 2: GUID (6 bytes, offset 16-21)
**References**: specs/testing/testing-strategy.md § Category 1: Unit Tests

## Instructions

### 1. Create GUID Factory Module

Create `src/yx/primitives/guid_factory.py`:

```python
"""
GUID Factory - Generate 6-byte sender identifiers.

Implements: specs/technical/yx-protocol-spec.md § Layer 2: GUID
"""

import os
from typing import Optional


class GUIDFactory:
    """Factory for generating and managing 6-byte GUIDs."""

    @staticmethod
    def generate() -> bytes:
        """
        Generate a new 6-byte GUID using cryptographically secure random bytes.

        Returns:
            bytes: 6 random bytes

        Example:
            >>> guid = GUIDFactory.generate()
            >>> len(guid)
            6
        """
        return os.urandom(6)

    @staticmethod
    def pad_guid(guid: bytes) -> bytes:
        """
        Pad a GUID to exactly 6 bytes with zero bytes.

        If GUID is longer than 6 bytes, truncate to 6 bytes.
        If GUID is shorter than 6 bytes, pad with zeros.

        Args:
            guid: Input bytes (any length)

        Returns:
            bytes: Exactly 6 bytes

        Example:
            >>> GUIDFactory.pad_guid(b'\\x01\\x02')
            b'\\x01\\x02\\x00\\x00\\x00\\x00'
            >>> GUIDFactory.pad_guid(b'\\x01\\x02\\x03\\x04\\x05\\x06\\x07\\x08')
            b'\\x01\\x02\\x03\\x04\\x05\\x06'
        """
        if len(guid) == 6:
            return guid
        elif len(guid) < 6:
            # Pad with zeros
            return guid + b'\x00' * (6 - len(guid))
        else:
            # Truncate to 6 bytes
            return guid[:6]

    @staticmethod
    def from_hex(hex_string: str) -> bytes:
        """
        Create GUID from hexadecimal string.

        Args:
            hex_string: Hex string (e.g., "010203040506")

        Returns:
            bytes: 6-byte GUID (padded if necessary)

        Raises:
            ValueError: If hex string is invalid

        Example:
            >>> GUIDFactory.from_hex("010203040506")
            b'\\x01\\x02\\x03\\x04\\x05\\x06'
        """
        guid_bytes = bytes.fromhex(hex_string)
        return GUIDFactory.pad_guid(guid_bytes)

    @staticmethod
    def to_hex(guid: bytes) -> str:
        """
        Convert GUID to hexadecimal string.

        Args:
            guid: 6-byte GUID

        Returns:
            str: Hex string (e.g., "010203040506")

        Example:
            >>> GUIDFactory.to_hex(b'\\x01\\x02\\x03\\x04\\x05\\x06')
            '010203040506'
        """
        return guid.hex()
```

### 2. Update Package __init__.py

Update `src/yx/primitives/__init__.py`:

```python
"""
YX Primitives - Core data structures and utilities.

Implements: specs/technical/yx-protocol-spec.md § Wire Format
"""

from .guid_factory import GUIDFactory

__all__ = ["GUIDFactory"]
```

### 3. Create Unit Tests

Create `tests/unit/test_guid_factory.py`:

```python
"""
Unit tests for GUID Factory.

Implements: specs/testing/testing-strategy.md § Category 1: Unit Tests
"""

import pytest
from yx.primitives import GUIDFactory


class TestGUIDFactory:
    """Test GUID generation and manipulation."""

    def test_generate_returns_6_bytes(self):
        """Test that generate() returns exactly 6 bytes."""
        guid = GUIDFactory.generate()
        assert len(guid) == 6
        assert isinstance(guid, bytes)

    def test_generate_produces_different_guids(self):
        """Test that generate() produces unique GUIDs."""
        guid1 = GUIDFactory.generate()
        guid2 = GUIDFactory.generate()
        # Very unlikely to be equal (1 in 2^48 chance)
        assert guid1 != guid2

    def test_generate_uses_secure_random(self):
        """Test that generate() produces non-zero GUIDs (secure random)."""
        # Generate 10 GUIDs and verify at least one has non-zero bytes
        guids = [GUIDFactory.generate() for _ in range(10)]
        # At least one should have non-zero bytes
        assert any(guid != b'\x00\x00\x00\x00\x00\x00' for guid in guids)

    def test_pad_guid_exact_6_bytes(self):
        """Test padding when GUID is already 6 bytes."""
        guid = b'\x01\x02\x03\x04\x05\x06'
        padded = GUIDFactory.pad_guid(guid)
        assert padded == guid
        assert len(padded) == 6

    def test_pad_guid_shorter_than_6_bytes(self):
        """Test padding when GUID is shorter than 6 bytes."""
        guid = b'\x01\x02'
        padded = GUIDFactory.pad_guid(guid)
        assert padded == b'\x01\x02\x00\x00\x00\x00'
        assert len(padded) == 6

    def test_pad_guid_empty(self):
        """Test padding empty GUID."""
        guid = b''
        padded = GUIDFactory.pad_guid(guid)
        assert padded == b'\x00\x00\x00\x00\x00\x00'
        assert len(padded) == 6

    def test_pad_guid_longer_than_6_bytes(self):
        """Test truncation when GUID is longer than 6 bytes."""
        guid = b'\x01\x02\x03\x04\x05\x06\x07\x08'
        padded = GUIDFactory.pad_guid(guid)
        assert padded == b'\x01\x02\x03\x04\x05\x06'
        assert len(padded) == 6

    def test_from_hex_valid(self):
        """Test creating GUID from hex string."""
        hex_string = "010203040506"
        guid = GUIDFactory.from_hex(hex_string)
        assert guid == b'\x01\x02\x03\x04\x05\x06'
        assert len(guid) == 6

    def test_from_hex_short_string(self):
        """Test creating GUID from short hex string (should pad)."""
        hex_string = "0102"
        guid = GUIDFactory.from_hex(hex_string)
        assert guid == b'\x01\x02\x00\x00\x00\x00'
        assert len(guid) == 6

    def test_from_hex_long_string(self):
        """Test creating GUID from long hex string (should truncate)."""
        hex_string = "0102030405060708"
        guid = GUIDFactory.from_hex(hex_string)
        assert guid == b'\x01\x02\x03\x04\x05\x06'
        assert len(guid) == 6

    def test_from_hex_invalid_string(self):
        """Test that invalid hex string raises ValueError."""
        with pytest.raises(ValueError):
            GUIDFactory.from_hex("INVALID")

    def test_to_hex_valid(self):
        """Test converting GUID to hex string."""
        guid = b'\x01\x02\x03\x04\x05\x06'
        hex_string = GUIDFactory.to_hex(guid)
        assert hex_string == "010203040506"

    def test_to_hex_with_zeros(self):
        """Test converting GUID with zeros to hex string."""
        guid = b'\x00\x01\x00\x02\x00\x03'
        hex_string = GUIDFactory.to_hex(guid)
        assert hex_string == "000100020003"

    def test_hex_roundtrip(self):
        """Test converting GUID to hex and back."""
        original = b'\xaa\xbb\xcc\xdd\xee\xff'
        hex_string = GUIDFactory.to_hex(original)
        restored = GUIDFactory.from_hex(hex_string)
        assert restored == original


# Additional edge case tests
class TestGUIDFactoryEdgeCases:
    """Test edge cases and boundary conditions."""

    def test_pad_guid_one_byte(self):
        """Test padding 1-byte GUID."""
        guid = b'\xff'
        padded = GUIDFactory.pad_guid(guid)
        assert padded == b'\xff\x00\x00\x00\x00\x00'

    def test_pad_guid_five_bytes(self):
        """Test padding 5-byte GUID."""
        guid = b'\x01\x02\x03\x04\x05'
        padded = GUIDFactory.pad_guid(guid)
        assert padded == b'\x01\x02\x03\x04\x05\x00'

    def test_from_hex_empty_string(self):
        """Test creating GUID from empty hex string."""
        guid = GUIDFactory.from_hex("")
        assert guid == b'\x00\x00\x00\x00\x00\x00'

    def test_to_hex_all_zeros(self):
        """Test converting all-zeros GUID to hex."""
        guid = b'\x00\x00\x00\x00\x00\x00'
        hex_string = GUIDFactory.to_hex(guid)
        assert hex_string == "000000000000"

    def test_to_hex_all_ones(self):
        """Test converting all-0xFF GUID to hex."""
        guid = b'\xff\xff\xff\xff\xff\xff'
        hex_string = GUIDFactory.to_hex(guid)
        assert hex_string == "ffffffffffff"
```

### 4. Run Tests

```bash
pytest tests/unit/test_guid_factory.py -v
```

### 5. Check Code Coverage

```bash
pytest tests/unit/test_guid_factory.py --cov=src/yx/primitives/guid_factory --cov-report=term-missing
```

**Expected**: 100% coverage

## Verification

**This step is complete when:**

- [ ] `src/yx/primitives/guid_factory.py` exists and implements all methods
- [ ] `tests/unit/test_guid_factory.py` exists with comprehensive tests
- [ ] All tests pass: `pytest tests/unit/test_guid_factory.py`
- [ ] Code coverage ≥ 100% for guid_factory.py
- [ ] GUIDFactory can be imported: `from yx.primitives import GUIDFactory`
- [ ] All methods work as specified

**Verification Commands:**

```bash
# Run tests
pytest tests/unit/test_guid_factory.py -v

# Check coverage
pytest tests/unit/test_guid_factory.py --cov=src/yx/primitives/guid_factory --cov-report=term-missing

# Verify import
python3 -c "from yx.primitives import GUIDFactory; guid = GUIDFactory.generate(); print(f'✓ Generated GUID: {guid.hex()}')"

# Verify methods
python3 -c "
from yx.primitives import GUIDFactory
guid = GUIDFactory.generate()
assert len(guid) == 6
padded = GUIDFactory.pad_guid(b'\\x01\\x02')
assert len(padded) == 6
hex_guid = GUIDFactory.to_hex(guid)
assert len(hex_guid) == 12
restored = GUIDFactory.from_hex(hex_guid)
assert restored == guid
print('✓ All GUID methods verified')
"
```

**Expected Output:**
```
test_guid_factory.py::TestGUIDFactory::test_generate_returns_6_bytes PASSED
test_guid_factory.py::TestGUIDFactory::test_generate_produces_different_guids PASSED
[... all tests pass ...]

---------- coverage: platform darwin, python 3.11.x -----------
Name                                    Stmts   Miss  Cover   Missing
---------------------------------------------------------------------
src/yx/primitives/guid_factory.py         23      0   100%
---------------------------------------------------------------------
TOTAL                                     23      0   100%

✓ Generated GUID: a1b2c3d4e5f6
✓ All GUID methods verified
```

**Retry Policy:**
- Maximum 3 attempts per test failure
- If tests fail: Review error messages, fix implementation, retry
- If coverage < 100%: Add missing tests
- If 3 failures: STOP and report error

## Notes

- GUID Factory is the simplest component - starts with minimal functionality
- Uses `os.urandom()` for cryptographically secure random bytes
- Padding ensures all GUIDs are exactly 6 bytes as required by protocol
- 100% test coverage establishes pattern for subsequent steps
- Hex conversion utilities aid debugging and testing
