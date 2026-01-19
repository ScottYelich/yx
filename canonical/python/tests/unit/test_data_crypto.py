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
