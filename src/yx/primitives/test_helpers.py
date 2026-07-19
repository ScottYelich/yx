"""
Test helpers for YX interoperability testing.

SimplePacketBuilder: synchronous packet builder for test senders.
Enables building and sending YX packets without the full async framework.

Traceability:
- protocol/specs/architecture/api-contracts.md (SimplePacketBuilder API)
- protocol/specs/testing/interoperability-requirements.md (Test Requirements)
"""

import json
import struct
import socket
import os
from typing import Dict, Any, List

from .data_compression import compress_data
from .data_crypto import encrypt_aes_gcm
from .data_chunking import chunk_data
from ..transport.packet_builder import PacketBuilder


class TestConfig:
    """
    Shared test configuration.

    Traceability:
    - protocol/specs/technical/default-values.md (test_port = 49999)
    - protocol/specs/testing/interoperability-requirements.md (Shared Configuration)
    """

    @staticmethod
    def test_port() -> int:
        """Test port (default: 49999, avoids conflict with 50000)."""
        return int(os.environ.get('TEST_YX_PORT', '49999'))

    @staticmethod
    def test_guid() -> bytes:
        """Fixed 6-byte test GUID (reproducible tests)."""
        return bytes([0x01] * 6)

    @staticmethod
    def test_key() -> bytes:
        """Fixed 32-byte test key (reproducible tests)."""
        return bytes(32)


class SimplePacketBuilder:
    """
    Pure function packet builder for test programs.

    No async, no state, no framework overhead.
    Build a packet, send it, exit.

    Traceability:
    - protocol/specs/architecture/api-contracts.md (SimplePacketBuilder)
    - protocol/specs/architecture/protocol-layers.md (Protocol 0, Protocol 1)
    """

    @staticmethod
    def build_text_packet(
        message: Dict[str, Any],
        guid: bytes,
        key: bytes
    ) -> bytes:
        """
        Build Protocol 0 (text/JSON) packet.

        Returns:
            Complete packet bytes: HMAC(16) + GUID(6) + [0x00] + JSON

        Traceability:
        - protocol/specs/architecture/protocol-layers.md (Protocol 0)
        """
        json_bytes = json.dumps(message).encode('utf-8')
        payload = bytes([0x00]) + json_bytes
        packet = PacketBuilder.build_packet(guid, payload, key)
        return packet.to_bytes()

    @staticmethod
    def build_binary_packet(
        data: bytes,
        guid: bytes,
        key: bytes,
        proto_opts: int = 0x00,
        channel_id: int = 0,
        sequence: int = 0,
        chunk_size: int = 1024
    ) -> List[bytes]:
        """
        Build Protocol 1 (binary) packets.

        Returns:
            List of packet bytes (one per chunk)

        Processing order: compress → encrypt → chunk

        Traceability:
        - protocol/specs/architecture/protocol-layers.md (Protocol 1)
        """
        # Compress if needed
        if proto_opts & 0x01:
            data = compress_data(data)

        # Encrypt if needed
        if proto_opts & 0x02:
            nonce, ct = encrypt_aes_gcm(data, key)
            data = nonce + ct

        chunks = chunk_data(data, chunk_size)
        total = len(chunks)

        # Header: proto(1) + protoOpts(1) + channelID(2) + seq(4) + chunkIdx(4) + totalChunks(4)
        HEADER_FMT = ">BBHIII"

        packets = []
        for i, chunk in enumerate(chunks):
            header = struct.pack(HEADER_FMT, 0x01, proto_opts, channel_id, sequence, i, total)
            payload = header + chunk
            packet = PacketBuilder.build_packet(guid, payload, key)
            packets.append(packet.to_bytes())

        return packets


def send_udp_packet(packet: bytes, host: str, port: int):
    """
    Send single UDP packet synchronously.

    Traceability:
    - protocol/specs/architecture/api-contracts.md (send_udp_packet)
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Increase send buffer for large packets (macOS default is 9216)
        needed = max(65507, len(packet) + 1024)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, needed)
        sock.sendto(packet, (host, port))
    finally:
        sock.close()


def send_udp_packets(packets: List[bytes], host: str, port: int):
    """
    Send multiple UDP packets synchronously.

    Traceability:
    - protocol/specs/architecture/api-contracts.md (send_udp_packets)
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Increase send buffer for large packets (macOS default is 9216)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 65507)
        for packet in packets:
            sock.sendto(packet, (host, port))
    finally:
        sock.close()
