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
