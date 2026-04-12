"""
Test helpers for YX interoperability testing.

Traceability:
- protocol/specs/architecture/api-contracts.md (SimplePacketBuilder API)
- protocol/specs/testing/interoperability-requirements.md (Test Requirements)
- protocol/specs/technical/default-values.md (Test configuration)

CRITICAL: SimplePacketBuilder enables interop tests without full framework.
This pattern was learned through SDTS development (3-4 days to discover).
"""

import json
import struct
import socket
import os
from typing import Dict, Any, List

from .data_compression import compress_data
from .data_crypto import encrypt_aes_gcm, compute_hmac
from .data_chunking import chunk_data
from ..transport.packet_builder import PacketBuilder


class TestConfig:
    """
    Test configuration utilities.

    Traceability:
    - protocol/specs/technical/default-values.md (test_port = 49999)
    - protocol/specs/architecture/api-contracts.md (TestConfig)
    """

    @staticmethod
    def test_port() -> int:
        """
        Get test port from environment or default.

        Returns:
            Port number (default: 49999, NOT 50000 to avoid conflict)

        Traceability:
        - protocol/specs/technical/default-values.md (test_port)
        """
        return int(os.environ.get('TEST_YX_PORT', '49999'))

    @staticmethod
    def test_guid() -> bytes:
        """
        Get fixed test GUID.

        Returns:
            6 bytes of 0x01 (for reproducible tests)

        Traceability:
        - protocol/specs/technical/default-values.md (test_guid)
        - protocol/specs/testing/interoperability-requirements.md (Shared Configuration)
        """
        return bytes([0x01] * 6)

    @staticmethod
    def test_key() -> bytes:
        """
        Get fixed test key.

        Returns:
            32 bytes of 0x00 (for reproducible tests)

        Traceability:
        - protocol/specs/technical/default-values.md (test_key)
        - protocol/specs/testing/interoperability-requirements.md (Shared Configuration)
        """
        return bytes(32)


class SimplePacketBuilder:
    """
    Pure function packet builder for test programs.

    Design:
    - Synchronous (no async)
    - Pure functions (no state)
    - Builds packets ready for UDP send

    Traceability:
    - protocol/specs/architecture/api-contracts.md (SimplePacketBuilder)
    - protocol/specs/architecture/protocol-layers.md (Protocol 0, Protocol 1)

    Usage Pattern:
        # Test sender program
        packet = SimplePacketBuilder.build_text_packet(message, guid, key)
        send_udp_packet(packet, "127.0.0.1", 49999)
        sys.exit(0)
    """

    @staticmethod
    def build_text_packet(
        message: Dict[str, Any],
        guid: bytes,
        key: bytes
    ) -> bytes:
        """
        Build Protocol 0 (text) packet.

        Args:
            message: JSON-serializable dict
            guid: 6-byte GUID
            key: 32-byte symmetric key

        Returns:
            Complete packet: [HMAC(16)] + [GUID(6)] + [0x00] + [JSON]

        Traceability:
        - protocol/specs/architecture/protocol-layers.md (Protocol 0)
        - protocol/specs/architecture/api-contracts.md (build_text_packet)
        """
        # Encode as JSON
        json_str = json.dumps(message)
        json_bytes = json_str.encode('utf-8')

        # Build Protocol 0 payload: [0x00] + [JSON]
        payload = bytes([0x00]) + json_bytes

        # Build packet with HMAC
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

        Args:
            data: Application data
            guid: 6-byte GUID
            key: 32-byte symmetric key
            proto_opts: Protocol options (0x00, 0x01, 0x02, 0x03)
            channel_id: Channel ID (0-65535)
            sequence: Sequence number (0-2^32-1)
            chunk_size: Chunk size in bytes (default: 1024)

        Returns:
            List of packets (one per chunk)

        Traceability:
        - protocol/specs/architecture/protocol-layers.md (Protocol 1)
        - protocol/specs/architecture/api-contracts.md (build_binary_packet)

        Processing order: compress → encrypt → chunk → build packets
        """
        # Compress if needed
        if proto_opts & 0x01:
            data = compress_data(data)

        # Encrypt if needed
        if proto_opts & 0x02:
            nonce, ciphertext_with_tag = encrypt_aes_gcm(data, key)
            data = nonce + ciphertext_with_tag

        # Chunk
        chunks = chunk_data(data, chunk_size)
        total_chunks = len(chunks)

        # Build packet for each chunk
        packets = []

        # Header format: proto(1) + protoOpts(1) + channelID(2) + sequence(4) + chunkIndex(4) + totalChunks(4)
        HEADER_FORMAT = ">BBHIII"

        for chunk_index, chunk in enumerate(chunks):
            # Build Protocol 1 header
            header = struct.pack(
                HEADER_FORMAT,
                0x01,  # Protocol ID: Binary
                proto_opts,
                channel_id,
                sequence,
                chunk_index,
                total_chunks
            )

            # Payload = header + chunk
            payload = header + chunk

            # Build packet with HMAC
            packet = PacketBuilder.build_packet(guid, payload, key)

            packets.append(packet.to_bytes())

        return packets


def send_udp_packet(packet: bytes, host: str, port: int) -> None:
    """
    Send single UDP packet using BSD socket.

    Args:
        packet: Complete packet bytes
        host: Destination IP
        port: Destination port

    Traceability:
    - protocol/specs/architecture/api-contracts.md (send_udp_packet)

    Note: Synchronous (no async needed for test senders)
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.sendto(packet, (host, port))
    finally:
        sock.close()


def send_udp_packets(packets: List[bytes], host: str, port: int) -> None:
    """
    Send multiple UDP packets using BSD socket.

    Args:
        packets: List of complete packet bytes
        host: Destination IP
        port: Destination port

    Traceability:
    - protocol/specs/architecture/api-contracts.md (send_udp_packets)
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        for packet in packets:
            sock.sendto(packet, (host, port))
    finally:
        sock.close()
