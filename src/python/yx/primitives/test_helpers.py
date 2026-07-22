"""
Test helpers for non-async packet building and sending

Provides pure functions for building YX packets and sending them synchronously
via BSD sockets. Useful for test programs that don't need full async/actor
machinery but still need protocol-compliant packet building.

Design Philosophy:
- Packet building is pure logic (HMAC, serialization) - doesn't need async
- UDP sending is just a syscall - doesn't need async
- Async/actors are great for production, but overkill for simple test senders
"""

import os
import socket
import struct
from typing import Dict, Any, List
from .guid import GUIDFactory
from .data_crypto import compute_hmac, encrypt_aes_gcm
from .data_compression import compress_data
from .json_utils import json_encode_bytes


class TestConfig:
    """Test configuration helpers"""

    @staticmethod
    def test_port() -> int:
        """
        Get test port from TEST_YX_PORT environment variable.

        Returns:
            int: Port number (default: 49999 for tests, NOT 50000 which is production)
        """
        port_str = os.environ.get('TEST_YX_PORT')
        if port_str:
            try:
                return int(port_str)
            except ValueError:
                pass
        return 49999  # Default test port (production uses 50000)


class SimplePacketBuilder:
    """Pure function packet builders (no async/actors needed)"""

    @staticmethod
    def build_text_packet(message: Dict[str, Any], guid: bytes, key: bytes) -> bytes:
        """
        Build Protocol 0 (Text/JSON) packet.

        Packet format: [HMAC(16)] + [GUID(6)] + [JSON]
        (No protocol-byte prefix: text is sniff-routed — first payload byte >= 32.)

        Args:
            message: JSON-serializable message (dict)
            guid: 6-byte GUID (will be padded if shorter)
            key: Symmetric key for HMAC

        Returns:
            bytes: Complete packet ready to send
        """
        # 1. Serialize JSON — this IS the Protocol 0 payload (no marker byte)
        payload = json_encode_bytes(message)

        # 2. Pad GUID to 6 bytes
        padded_guid = GUIDFactory.pad_guid(guid)

        # 3. Calculate HMAC over GUID + payload
        hmac_input = padded_guid + payload
        hmac_value = compute_hmac(hmac_input, key, truncate_to=16)

        # 4. Assemble: [HMAC(16)] + [GUID(6)] + [payload]
        packet = hmac_value + padded_guid + payload
        return packet

    @staticmethod
    def build_binary_packet(
        data: bytes,
        guid: bytes,
        key: bytes,
        proto_opts: int = 0x00,
        channel_id: int = 1,
        sequence: int = 0,
        chunk_size: int = 1024
    ) -> List[bytes]:
        """
        Build Protocol 1 (Binary/Chunked) packet(s).

        Packet format per chunk:
        [HMAC(16)] + [GUID(6)] + [protoID(1)] + [protoOpts(1)] + [channelID(2)] +
        [sequence(4)] + [chunkIndex(4)] + [totalChunks(4)] + [chunk_data]

        Args:
            data: Binary data to send
            guid: 6-byte GUID
            key: Symmetric key for HMAC and encryption
            proto_opts: Protocol options (0x00-0x03)
                       0x00: No compression/encryption
                       0x01: Compression
                       0x02: Encryption
                       0x03: Both
            channel_id: Logical channel (0-65535, default=1)
            sequence: Message sequence number (0-2^32-1)
            chunk_size: Maximum chunk size (default: 1024)

        Returns:
            List[bytes]: List of complete packets (one per chunk)
        """
        # Step 1: Compress if requested
        encoded_data = data
        if proto_opts & 0x01:  # PROTO_OPTS_COMPRESS
            encoded_data = compress_data(encoded_data)

        # Step 2: Encrypt if requested (BEFORE chunking)
        if proto_opts & 0x02:  # PROTO_OPTS_ENCRYPT
            nonce, ciphertext = encrypt_aes_gcm(encoded_data, key)
            encoded_data = nonce + ciphertext

        # Step 3: Chunk the data
        chunks = []
        offset = 0
        while offset < len(encoded_data):
            chunk = encoded_data[offset:offset + chunk_size]
            chunks.append(chunk)
            offset += chunk_size

        total_chunks = len(chunks)

        # Step 4: Build packets with headers
        packets = []
        padded_guid = GUIDFactory.pad_guid(guid)

        for chunk_index, chunk in enumerate(chunks):
            # Build payload header (Protocol 1 format)
            # [protoID(1)] + [protoOpts(1)] + [channelID(2)] + [sequence(4)] +
            # [chunkIndex(4)] + [totalChunks(4)]
            header = struct.pack(
                '>BBHIII',
                0x01,           # protoID
                proto_opts,     # protoOpts
                channel_id,     # channelID (2 bytes, big-endian)
                sequence,       # sequence (4 bytes, big-endian)
                chunk_index,    # chunkIndex
                total_chunks    # totalChunks
            )
            payload = header + chunk

            # Calculate HMAC over GUID + payload
            hmac_input = padded_guid + payload
            hmac_value = compute_hmac(hmac_input, key, truncate_to=16)

            # Assemble: [HMAC(16)] + [GUID(6)] + [payload]
            packet = hmac_value + padded_guid + payload
            packets.append(packet)

        return packets


def send_udp_packet(packet: bytes, host: str, port: int) -> None:
    """
    Send UDP packet synchronously using BSD sockets.

    Args:
        packet: Complete packet bytes to send
        host: Destination host (IP address or broadcast)
        port: Destination port

    Raises:
        OSError: If socket operations fail
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Enable broadcast if needed
        if host == '255.255.255.255':
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

        # Send packet
        bytes_sent = sock.sendto(packet, (host, port))

        if bytes_sent != len(packet):
            raise OSError(f"Incomplete send: {bytes_sent}/{len(packet)} bytes")

    finally:
        sock.close()


def send_udp_packets(packets: List[bytes], host: str, port: int) -> None:
    """
    Send multiple UDP packets synchronously (for chunked binary protocol).

    Args:
        packets: List of packet bytes to send
        host: Destination host
        port: Destination port

    Raises:
        OSError: If socket operations fail
    """
    for packet in packets:
        send_udp_packet(packet, host, port)
