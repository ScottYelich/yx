"""Tests for test helpers (SimplePacketBuilder, TestConfig)."""

import pytest
import os
from yx.primitives.test_helpers import TestConfig, SimplePacketBuilder, send_udp_packet, send_udp_packets
from yx.transport.packet_builder import PacketBuilder


def test_config_port():
    assert TestConfig.test_port() == 49999


def test_config_guid():
    guid = TestConfig.test_guid()
    assert len(guid) == 6
    assert guid == bytes([0x01] * 6)


def test_config_key():
    key = TestConfig.test_key()
    assert len(key) == 32
    assert key == bytes(32)


def test_build_text_packet():
    guid = os.urandom(6)
    key = os.urandom(32)
    message = {"method": "test", "params": {"value": 42}}

    packet_bytes = SimplePacketBuilder.build_text_packet(message, guid, key)
    assert len(packet_bytes) >= 22

    packet = PacketBuilder.parse_packet(packet_bytes)
    assert packet is not None
    assert packet.guid == guid
    assert PacketBuilder.validate_hmac(packet, key)
    assert packet.payload[0] == 0x00

    import json
    parsed = json.loads(packet.payload[1:].decode('utf-8'))
    assert parsed == message


def test_build_binary_single_chunk():
    guid = os.urandom(6)
    key = os.urandom(32)
    data = b"Small data"

    packets = SimplePacketBuilder.build_binary_packet(data, guid, key, proto_opts=0x00)
    assert len(packets) == 1

    packet = PacketBuilder.parse_packet(packets[0])
    assert packet is not None
    assert PacketBuilder.validate_hmac(packet, key)
    assert packet.payload[0] == 0x01


def test_build_binary_multi_chunk():
    guid = os.urandom(6)
    key = os.urandom(32)
    data = b"A" * 2500

    packets = SimplePacketBuilder.build_binary_packet(
        data, guid, key, proto_opts=0x00, chunk_size=1024
    )
    assert len(packets) == 3


def test_build_binary_compressed():
    guid = os.urandom(6)
    key = os.urandom(32)
    packets = SimplePacketBuilder.build_binary_packet(
        b"Hello! " * 100, guid, key, proto_opts=0x01
    )
    assert len(packets) >= 1


def test_build_binary_encrypted():
    guid = os.urandom(6)
    key = os.urandom(32)
    packets = SimplePacketBuilder.build_binary_packet(
        b"Secret!", guid, key, proto_opts=0x02
    )
    assert len(packets) >= 1


def test_build_binary_both():
    guid = os.urandom(6)
    key = os.urandom(32)
    packets = SimplePacketBuilder.build_binary_packet(
        b"Secret! " * 100, guid, key, proto_opts=0x03
    )
    assert len(packets) >= 1
