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
