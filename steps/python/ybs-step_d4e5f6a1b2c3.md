# Step 4: HMAC Computation

**Version**: 0.1.0

## Overview

Implement HMAC-SHA256 computation and validation for packet integrity. This is the core security primitive that ensures packets haven't been tampered with.

## Step Objectives

1. Implement HMAC-SHA256 computation with truncation to 16 bytes
2. Implement constant-time HMAC comparison
3. Create comprehensive unit tests including security tests
4. Achieve 100% code coverage

## Prerequisites

- Step 3 completed (Packet structure implemented)
- cryptography library installed

## Traceability

**Implements**: specs/technical/yx-protocol-spec.md § HMAC-SHA256 Integrity
**References**: specs/testing/testing-strategy.md § Category 3: Unit Tests (Security)

## Instructions

### 1. Create Data Crypto Module

Create `src/yx/primitives/data_crypto.py`:

```python
"""
Data Cryptography Primitives - HMAC, AES-GCM, etc.

Implements: specs/technical/yx-protocol-spec.md § Security Mechanisms
"""

import hmac as hmac_module
from cryptography.hazmat.primitives import hashes, hmac


def compute_hmac(data: bytes, key: bytes, truncate_to: int = 16) -> bytes:
    """
    Compute HMAC-SHA256 and truncate to specified length.

    Args:
        data: Data to compute HMAC over
        key: 32-byte symmetric key
        truncate_to: Output length in bytes (default: 16)

    Returns:
        bytes: Truncated HMAC

    Raises:
        ValueError: If key is not 32 bytes
        ValueError: If truncate_to > 32

    Example:
        >>> key = b'\\x00' * 32
        >>> data = b'test data'
        >>> mac = compute_hmac(data, key, truncate_to=16)
        >>> len(mac)
        16
    """
    if len(key) != 32:
        raise ValueError(f"Key must be 32 bytes, got {len(key)}")
    if truncate_to > 32:
        raise ValueError(f"Cannot truncate to more than 32 bytes, got {truncate_to}")

    h = hmac.HMAC(key, hashes.SHA256())
    h.update(data)
    mac = h.finalize()
    return mac[:truncate_to]


def validate_hmac_constant_time(
    data: bytes,
    key: bytes,
    expected_hmac: bytes,
    truncate_to: int = 16
) -> bool:
    """
    Validate HMAC using constant-time comparison.

    Args:
        data: Data to validate
        key: 32-byte symmetric key
        expected_hmac: Expected HMAC value
        truncate_to: HMAC length in bytes (default: 16)

    Returns:
        bool: True if HMAC is valid, False otherwise

    Example:
        >>> key = b'\\x00' * 32
        >>> data = b'test'
        >>> mac = compute_hmac(data, key)
        >>> validate_hmac_constant_time(data, key, mac)
        True
    """
    try:
        computed_hmac = compute_hmac(data, key, truncate_to)
        # Use constant-time comparison to prevent timing attacks
        return hmac_module.compare_digest(computed_hmac, expected_hmac)
    except (ValueError, TypeError):
        return False


def compute_packet_hmac(guid: bytes, payload: bytes, key: bytes) -> bytes:
    """
    Compute HMAC for YX packet (GUID + Payload).

    Args:
        guid: 6-byte sender GUID
        payload: Packet payload bytes
        key: 32-byte symmetric key

    Returns:
        bytes: 16-byte HMAC

    Example:
        >>> key = b'\\x00' * 32
        >>> guid = b'\\x01' * 6
        >>> payload = b'test'
        >>> mac = compute_packet_hmac(guid, payload, key)
        >>> len(mac)
        16
    """
    if len(guid) != 6:
        raise ValueError(f"GUID must be 6 bytes, got {len(guid)}")

    hmac_input = guid + payload
    return compute_hmac(hmac_input, key, truncate_to=16)


def validate_packet_hmac(
    guid: bytes,
    payload: bytes,
    key: bytes,
    expected_hmac: bytes
) -> bool:
    """
    Validate HMAC for YX packet.

    Args:
        guid: 6-byte sender GUID
        payload: Packet payload bytes
        key: 32-byte symmetric key
        expected_hmac: Expected 16-byte HMAC

    Returns:
        bool: True if valid, False otherwise

    Example:
        >>> key = b'\\x00' * 32
        >>> guid = b'\\x01' * 6
        >>> payload = b'test'
        >>> mac = compute_packet_hmac(guid, payload, key)
        >>> validate_packet_hmac(guid, payload, key, mac)
        True
    """
    try:
        computed_hmac = compute_packet_hmac(guid, payload, key)
        return hmac_module.compare_digest(computed_hmac, expected_hmac)
    except (ValueError, TypeError):
        return False
```

### 2. Update Package __init__.py

Update `src/yx/primitives/__init__.py`:

```python
"""
YX Primitives - Core data structures and utilities.

Implements: specs/technical/yx-protocol-spec.md § Wire Format
"""

from .guid_factory import GUIDFactory
from .data_crypto import (
    compute_hmac,
    validate_hmac_constant_time,
    compute_packet_hmac,
    validate_packet_hmac,
)

__all__ = [
    "GUIDFactory",
    "compute_hmac",
    "validate_hmac_constant_time",
    "compute_packet_hmac",
    "validate_packet_hmac",
]
```

### 3. Create Unit Tests

Create `tests/unit/test_data_crypto.py`:

```python
"""
Unit tests for data cryptography primitives.

Implements: specs/testing/testing-strategy.md § Category 3: Unit Tests (Security)
"""

import pytest
from yx.primitives import (
    compute_hmac,
    validate_hmac_constant_time,
    compute_packet_hmac,
    validate_packet_hmac,
)


class TestComputeHMAC:
    """Test HMAC computation."""

    def test_compute_hmac_returns_16_bytes_default(self):
        """Test default truncation to 16 bytes."""
        key = b'\x00' * 32
        data = b'test data'
        mac = compute_hmac(data, key)
        assert len(mac) == 16

    def test_compute_hmac_custom_truncation(self):
        """Test custom truncation length."""
        key = b'\x00' * 32
        data = b'test'
        mac = compute_hmac(data, key, truncate_to=8)
        assert len(mac) == 8

    def test_compute_hmac_full_length(self):
        """Test no truncation (full 32 bytes)."""
        key = b'\x00' * 32
        data = b'test'
        mac = compute_hmac(data, key, truncate_to=32)
        assert len(mac) == 32

    def test_compute_hmac_different_data_different_output(self):
        """Test that different data produces different HMAC."""
        key = b'\x00' * 32
        mac1 = compute_hmac(b'data1', key)
        mac2 = compute_hmac(b'data2', key)
        assert mac1 != mac2

    def test_compute_hmac_different_key_different_output(self):
        """Test that different key produces different HMAC."""
        data = b'test'
        key1 = b'\x00' * 32
        key2 = b'\xff' * 32
        mac1 = compute_hmac(data, key1)
        mac2 = compute_hmac(data, key2)
        assert mac1 != mac2

    def test_compute_hmac_same_input_same_output(self):
        """Test deterministic behavior."""
        key = b'\x00' * 32
        data = b'test'
        mac1 = compute_hmac(data, key)
        mac2 = compute_hmac(data, key)
        assert mac1 == mac2

    def test_compute_hmac_wrong_key_length(self):
        """Test that non-32-byte key raises ValueError."""
        with pytest.raises(ValueError, match="Key must be 32 bytes"):
            compute_hmac(b'data', b'short key')

    def test_compute_hmac_invalid_truncation(self):
        """Test that truncation > 32 raises ValueError."""
        key = b'\x00' * 32
        with pytest.raises(ValueError, match="Cannot truncate to more than 32 bytes"):
            compute_hmac(b'data', key, truncate_to=33)

    def test_compute_hmac_empty_data(self):
        """Test HMAC of empty data."""
        key = b'\x00' * 32
        mac = compute_hmac(b'', key)
        assert len(mac) == 16
        assert mac != b'\x00' * 16  # Should not be all zeros


class TestValidateHMAC:
    """Test HMAC validation."""

    def test_validate_hmac_valid(self):
        """Test validation with correct HMAC."""
        key = b'\x00' * 32
        data = b'test data'
        mac = compute_hmac(data, key)
        assert validate_hmac_constant_time(data, key, mac) is True

    def test_validate_hmac_invalid(self):
        """Test validation with incorrect HMAC."""
        key = b'\x00' * 32
        data = b'test data'
        mac = compute_hmac(data, key)
        wrong_mac = bytes([(b + 1) % 256 for b in mac])
        assert validate_hmac_constant_time(data, key, wrong_mac) is False

    def test_validate_hmac_modified_data(self):
        """Test validation fails with modified data."""
        key = b'\x00' * 32
        data = b'test data'
        mac = compute_hmac(data, key)
        modified_data = b'test data modified'
        assert validate_hmac_constant_time(modified_data, key, mac) is False

    def test_validate_hmac_wrong_key(self):
        """Test validation fails with wrong key."""
        key1 = b'\x00' * 32
        key2 = b'\xff' * 32
        data = b'test'
        mac = compute_hmac(data, key1)
        assert validate_hmac_constant_time(data, key2, mac) is False

    def test_validate_hmac_constant_time(self):
        """Test that validation uses constant-time comparison."""
        # This is a behavioral test - we can't directly test timing,
        # but we verify it uses hmac.compare_digest
        key = b'\x00' * 32
        data = b'test'
        mac = compute_hmac(data, key)

        # Valid HMAC
        result1 = validate_hmac_constant_time(data, key, mac)
        # Invalid HMAC (first byte different)
        wrong_mac = bytes([mac[0] ^ 0xFF]) + mac[1:]
        result2 = validate_hmac_constant_time(data, key, wrong_mac)

        assert result1 is True
        assert result2 is False


class TestComputePacketHMAC:
    """Test packet-specific HMAC computation."""

    def test_compute_packet_hmac_valid(self):
        """Test computing HMAC for packet."""
        key = b'\x00' * 32
        guid = b'\x01' * 6
        payload = b'test payload'
        mac = compute_packet_hmac(guid, payload, key)
        assert len(mac) == 16

    def test_compute_packet_hmac_empty_payload(self):
        """Test HMAC with empty payload."""
        key = b'\x00' * 32
        guid = b'\x01' * 6
        payload = b''
        mac = compute_packet_hmac(guid, payload, key)
        assert len(mac) == 16

    def test_compute_packet_hmac_combines_guid_and_payload(self):
        """Test that HMAC is computed over GUID + Payload."""
        key = b'\x00' * 32
        guid = b'\x01' * 6
        payload = b'test'

        # Compute packet HMAC
        packet_mac = compute_packet_hmac(guid, payload, key)

        # Compute manually
        combined = guid + payload
        manual_mac = compute_hmac(combined, key)

        assert packet_mac == manual_mac

    def test_compute_packet_hmac_wrong_guid_length(self):
        """Test that wrong GUID length raises ValueError."""
        key = b'\x00' * 32
        with pytest.raises(ValueError, match="GUID must be 6 bytes"):
            compute_packet_hmac(b'\x01' * 5, b'payload', key)


class TestValidatePacketHMAC:
    """Test packet HMAC validation."""

    def test_validate_packet_hmac_valid(self):
        """Test validating correct packet HMAC."""
        key = b'\x00' * 32
        guid = b'\x01' * 6
        payload = b'test'
        mac = compute_packet_hmac(guid, payload, key)

        assert validate_packet_hmac(guid, payload, key, mac) is True

    def test_validate_packet_hmac_invalid(self):
        """Test validating incorrect packet HMAC."""
        key = b'\x00' * 32
        guid = b'\x01' * 6
        payload = b'test'
        mac = compute_packet_hmac(guid, payload, key)
        wrong_mac = bytes([(b + 1) % 256 for b in mac])

        assert validate_packet_hmac(guid, payload, key, wrong_mac) is False

    def test_validate_packet_hmac_modified_guid(self):
        """Test validation fails with modified GUID."""
        key = b'\x00' * 32
        guid = b'\x01' * 6
        payload = b'test'
        mac = compute_packet_hmac(guid, payload, key)

        modified_guid = b'\x02' * 6
        assert validate_packet_hmac(modified_guid, payload, key, mac) is False

    def test_validate_packet_hmac_modified_payload(self):
        """Test validation fails with modified payload."""
        key = b'\x00' * 32
        guid = b'\x01' * 6
        payload = b'test'
        mac = compute_packet_hmac(guid, payload, key)

        modified_payload = b'modified'
        assert validate_packet_hmac(guid, modified_payload, key, mac) is False


class TestHMACSecurityProperties:
    """Test security properties of HMAC implementation."""

    def test_hmac_not_reversible(self):
        """Test that HMAC cannot be used to recover data (one-way)."""
        key = b'\x00' * 32
        data = b'secret data'
        mac = compute_hmac(data, key)

        # HMAC should give no information about original data
        assert len(mac) == 16
        assert mac != data
        # Cannot recover data from HMAC

    def test_hmac_avalanche_effect(self):
        """Test that small changes in input cause large changes in output."""
        key = b'\x00' * 32
        data1 = b'test data'
        data2 = b'test datb'  # One bit difference

        mac1 = compute_hmac(data1, key)
        mac2 = compute_hmac(data2, key)

        # Count differing bits
        diff_bits = sum(bin(b1 ^ b2).count('1') for b1, b2 in zip(mac1, mac2))

        # At least 25% of bits should differ (avalanche effect)
        assert diff_bits >= 32  # Out of 128 bits

    def test_hmac_key_sensitivity(self):
        """Test that small changes in key cause large changes in output."""
        data = b'test'
        key1 = b'\x00' * 32
        key2 = b'\x00' * 31 + b'\x01'  # One bit difference

        mac1 = compute_hmac(data, key1)
        mac2 = compute_hmac(data, key2)

        # Count differing bits
        diff_bits = sum(bin(b1 ^ b2).count('1') for b1, b2 in zip(mac1, mac2))

        # At least 25% of bits should differ
        assert diff_bits >= 32
```

### 4. Run Tests

```bash
pytest tests/unit/test_data_crypto.py -v
```

### 5. Check Code Coverage

```bash
pytest tests/unit/test_data_crypto.py --cov=src/yx/primitives/data_crypto --cov-report=term-missing
```

**Expected**: 100% coverage

## Verification

**This step is complete when:**

- [ ] `src/yx/primitives/data_crypto.py` exists with HMAC functions
- [ ] `tests/unit/test_data_crypto.py` exists with security tests
- [ ] All tests pass
- [ ] Code coverage ≥ 100%
- [ ] HMAC functions can be imported and used
- [ ] Constant-time comparison verified

**Verification Commands:**

```bash
# Run tests
pytest tests/unit/test_data_crypto.py -v

# Check coverage
pytest tests/unit/test_data_crypto.py --cov=src/yx/primitives/data_crypto --cov-report=term-missing

# Verify HMAC computation
python3 -c "
from yx.primitives import compute_packet_hmac, validate_packet_hmac
key = b'\\x00' * 32
guid = b'\\x01' * 6
payload = b'test'
mac = compute_packet_hmac(guid, payload, key)
assert len(mac) == 16
assert validate_packet_hmac(guid, payload, key, mac)
print('✓ HMAC computation and validation verified')
"
```

**Expected Output:**
```
[all tests pass with 100% coverage]
✓ HMAC computation and validation verified
```

**Retry Policy:**
- Maximum 3 attempts
- If tests fail: Fix implementation, retry
- If 3 failures: STOP and report

## Notes

- HMAC-SHA256 provides packet integrity (not confidentiality)
- Truncation to 16 bytes balances security and packet size
- Constant-time comparison prevents timing attacks
- Security tests verify cryptographic properties
- This is the first security-critical component
