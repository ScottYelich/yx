"""Unit tests for Packet Parser and Validator."""

import pytest
from yx.transport import PacketBuilder, Packet


class TestParsePacket:
    """Test packet parsing (no validation)."""

    def test_parse_valid_packet(self):
        """Test parsing valid packet."""
        key = b'\x00' * 32
        data = PacketBuilder.build_and_serialize(b'\x01'*6, b'test', key)

        packet = PacketBuilder.parse_packet(data)

        assert packet is not None
        assert packet.payload == b'test'

    def test_parse_packet_too_short(self):
        """Test that short data returns None."""
        packet = PacketBuilder.parse_packet(b'\x00' * 21)
        assert packet is None


class TestValidateHMAC:
    """Test HMAC validation."""

    def test_validate_hmac_valid_packet(self):
        """Test validating packet with correct HMAC."""
        key = b'\x00' * 32
        packet = PacketBuilder.build_packet(b'\x01'*6, b'test', key)

        assert PacketBuilder.validate_hmac(packet, key) is True

    def test_validate_hmac_invalid_packet(self):
        """Test validation fails with wrong HMAC."""
        key = b'\x00' * 32
        packet = Packet(hmac=b'\xff'*16, guid=b'\x01'*6, payload=b'test')

        assert PacketBuilder.validate_hmac(packet, key) is False


class TestParseAndValidate:
    """Test combined parsing and validation."""

    def test_parse_and_validate_valid_packet(self):
        """Test parsing and validating valid packet."""
        key = b'\x00' * 32
        data = PacketBuilder.build_and_serialize(b'\x01'*6, b'test', key)

        packet = PacketBuilder.parse_and_validate(data, key)

        assert packet is not None
        assert packet.payload == b'test'

    def test_parse_and_validate_invalid_hmac(self):
        """Test that invalid HMAC returns None."""
        key = b'\x00' * 32
        # Build with one key, validate with another
        data = PacketBuilder.build_and_serialize(b'\x01'*6, b'test', b'\xff'*32)

        packet = PacketBuilder.parse_and_validate(data, key)

        assert packet is None

    def test_parse_and_validate_corrupted_data(self):
        """Test handling corrupted packet."""
        key = b'\x00' * 32
        data = PacketBuilder.build_and_serialize(b'\x01'*6, b'test', key)

        # Corrupt one byte in payload
        corrupted = data[:23] + bytes([(data[23] ^ 0xFF)]) + data[24:]

        packet = PacketBuilder.parse_and_validate(corrupted, key)

        assert packet is None  # HMAC validation fails

    def test_parse_and_validate_roundtrip(self):
        """Test full roundtrip: build → serialize → parse → validate."""
        key = b'\x00' * 32
        guid = b'\xaa' * 6
        payload = b'test payload data'

        data = PacketBuilder.build_and_serialize(guid, payload, key)
        packet = PacketBuilder.parse_and_validate(data, key)

        assert packet is not None
        assert packet.guid == guid
        assert packet.payload == payload
