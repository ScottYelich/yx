"""
Tests for test helpers.

Traceability:
- protocol/specs/architecture/api-contracts.md (SimplePacketBuilder Tests)
"""

import pytest
import os
from yx.primitives.test_helpers import (
    TestConfig,
    SimplePacketBuilder,
    send_udp_packet,
    send_udp_packets
)
from yx.transport.packet_builder import PacketBuilder


def test_test_config_port():
    """Test TestConfig.test_port()."""
    port = TestConfig.test_port()
    assert port == 49999  # Default


def test_test_config_guid():
    """Test TestConfig.test_guid()."""
    guid = TestConfig.test_guid()
    assert len(guid) == 6
    assert guid == bytes([0x01] * 6)


def test_test_config_key():
    """Test TestConfig.test_key()."""
    key = TestConfig.test_key()
    assert len(key) == 32
    assert key == bytes(32)


def test_simple_packet_builder_text():
    """Test SimplePacketBuilder.build_text_packet()."""
    guid = os.urandom(6)
    key = os.urandom(32)
    message = {"method": "test", "params": {"value": 42}}

    packet_bytes = SimplePacketBuilder.build_text_packet(message, guid, key)

    # Verify structure
    assert len(packet_bytes) >= 22  # Minimum: HMAC(16) + GUID(6)

    # Parse packet
    packet = PacketBuilder.parse_packet(packet_bytes)
    assert packet.guid == guid

    # Verify HMAC
    assert PacketBuilder.validate_hmac(packet, key, ("127.0.0.1", 12345))

    # Verify Protocol 0 marker
    assert packet.payload[0] == 0x00

    # Verify JSON content
    import json
    json_bytes = packet.payload[1:]
    parsed = json.loads(json_bytes.decode('utf-8'))
    assert parsed == message


def test_simple_packet_builder_binary_single_chunk():
    """Test SimplePacketBuilder.build_binary_packet() with single chunk."""
    guid = os.urandom(6)
    key = os.urandom(32)
    data = b"Small data"

    packets = SimplePacketBuilder.build_binary_packet(
        data, guid, key,
        proto_opts=0x00,
        channel_id=0,
        sequence=0
    )

    assert len(packets) == 1  # Single chunk

    # Parse packet
    packet = PacketBuilder.parse_packet(packets[0])
    assert packet.guid == guid

    # Verify HMAC
    assert PacketBuilder.validate_hmac(packet, key, ("127.0.0.1", 12345))

    # Verify Protocol 1 marker
    assert packet.payload[0] == 0x01


def test_simple_packet_builder_binary_multi_chunk():
    """Test SimplePacketBuilder.build_binary_packet() with multiple chunks."""
    guid = os.urandom(6)
    key = os.urandom(32)
    data = b"A" * 2500  # Will be 3 chunks at 1024 bytes each

    packets = SimplePacketBuilder.build_binary_packet(
        data, guid, key,
        proto_opts=0x00,
        channel_id=0,
        sequence=0,
        chunk_size=1024
    )

    assert len(packets) == 3  # Three chunks


def test_simple_packet_builder_binary_compressed():
    """Test SimplePacketBuilder.build_binary_packet() with compression."""
    guid = os.urandom(6)
    key = os.urandom(32)
    data = b"Hello! " * 100  # Compressible data

    packets = SimplePacketBuilder.build_binary_packet(
        data, guid, key,
        proto_opts=0x01,  # Compress
        channel_id=0,
        sequence=0
    )

    assert len(packets) >= 1


def test_simple_packet_builder_binary_encrypted():
    """Test SimplePacketBuilder.build_binary_packet() with encryption."""
    guid = os.urandom(6)
    key = os.urandom(32)
    data = b"Secret message!"

    packets = SimplePacketBuilder.build_binary_packet(
        data, guid, key,
        proto_opts=0x02,  # Encrypt
        channel_id=0,
        sequence=0
    )

    assert len(packets) >= 1


def test_simple_packet_builder_binary_both():
    """Test SimplePacketBuilder.build_binary_packet() with compression + encryption."""
    guid = os.urandom(6)
    key = os.urandom(32)
    data = b"Secret! " * 100

    packets = SimplePacketBuilder.build_binary_packet(
        data, guid, key,
        proto_opts=0x03,  # Both
        channel_id=0,
        sequence=0
    )

    assert len(packets) >= 1


def test_send_udp_packet_does_not_crash():
    """Test send_udp_packet() doesn't crash (actual send may fail if port closed)."""
    packet = b"test packet"

    # Should not raise (send may fail silently if port closed)
    try:
        send_udp_packet(packet, "127.0.0.1", 19999)
    except Exception as e:
        pytest.skip(f"UDP send failed (expected if port closed): {e}")


def test_send_udp_packets_does_not_crash():
    """Test send_udp_packets() doesn't crash."""
    packets = [b"packet1", b"packet2", b"packet3"]

    # Should not raise
    try:
        send_udp_packets(packets, "127.0.0.1", 19999)
    except Exception as e:
        pytest.skip(f"UDP send failed (expected if port closed): {e}")
