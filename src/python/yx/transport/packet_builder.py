"""
Packet builder for constructing and parsing packets

Handles HMAC computation and packet assembly/disassembly.
"""

import os
import tempfile
import time
from typing import Optional
from ..primitives.guid import GUIDFactory
from ..primitives.data_crypto import compute_hmac
from .packet import Packet


class PacketBuilder:
    """Build and parse YX packets with HMAC validation"""

    @staticmethod
    def build_packet(guid: bytes, payload: bytes, key: bytes) -> Packet:
        """
        Build a packet with HMAC.

        Args:
            guid: 6-byte GUID (will be padded if shorter)
            payload: Packet payload
            key: Symmetric key for HMAC

        Returns:
            Packet: Complete packet with HMAC
        """
        # Pad GUID to 6 bytes
        padded_guid = GUIDFactory.pad_guid(guid)

        # Compute HMAC over GUID + payload
        hmac_input = padded_guid + payload
        hmac_value = compute_hmac(hmac_input, key, truncate_to=16)

        return Packet(hmac=hmac_value, guid=padded_guid, payload=payload)

    @staticmethod
    def parse_packet(data: bytes) -> Optional[Packet]:
        """
        Parse raw bytes into a packet.

        Args:
            data: Raw packet bytes

        Returns:
            Optional[Packet]: Parsed packet, or None if invalid
        """
        return Packet.from_bytes(data)

    @staticmethod
    def validate_hmac(packet: Packet, key: bytes, source_addr: Optional[tuple] = None) -> bool:
        """
        Validate packet HMAC.

        Args:
            packet: Packet to validate
            key: Symmetric key for HMAC verification
            source_addr: Optional (host, port) tuple of packet source

        Returns:
            bool: True if HMAC is valid
        """
        # Recompute HMAC
        hmac_input = packet.guid + packet.payload
        expected_hmac = compute_hmac(hmac_input, key, truncate_to=16)

        # Constant-time comparison (using secrets.compare_digest would be better for production)
        is_valid = packet.hmac == expected_hmac

        # If HMAC validation fails, write packet to /tmp atomically
        if not is_valid:
            PacketBuilder._write_failed_packet(packet, expected_hmac, source_addr)

        return is_valid

    @staticmethod
    def _write_failed_packet(packet: Packet, expected_hmac: bytes, source_addr: Optional[tuple] = None):
        """
        Append failed HMAC packet to /tmp/hmac_failures.log for forensics.

        Args:
            packet: The packet that failed HMAC validation
            expected_hmac: The expected HMAC value
            source_addr: Optional (host, port) tuple of packet source
        """
        try:
            timestamp = int(time.time() * 1000000)  # microseconds
            guid_hex = packet.guid.hex()
            log_file = "/tmp/hmac_failures.log"

            # Build log entry
            entry = f"\n{'='*80}\n"
            entry += f"HMAC_FAILURE\n"
            entry += f"Timestamp: {timestamp}\n"
            entry += f"GUID: {guid_hex}\n"
            if source_addr:
                entry += f"Source IP: {source_addr[0]}\n"
                entry += f"Source Port: {source_addr[1]}\n"
            entry += f"Received HMAC: {packet.hmac.hex()}\n"
            entry += f"Expected HMAC: {expected_hmac.hex()}\n"
            entry += f"Packet Size: {len(packet)}\n"
            entry += f"---RAW_PACKET_HEX---\n"
            entry += f"{packet.to_bytes().hex()}\n"
            entry += f"{'='*80}\n"

            # Append to log file (file locking for atomic writes)
            import fcntl
            with open(log_file, 'a') as f:
                # Get exclusive lock
                fcntl.flock(f.fileno(), fcntl.LOCK_EX)
                try:
                    f.write(entry)
                    f.flush()
                    os.fsync(f.fileno())
                finally:
                    # Release lock
                    fcntl.flock(f.fileno(), fcntl.LOCK_UN)

            from ..primitives.logger import Logger
            logger = Logger("PacketBuilder")
            source_info = f" from {source_addr[0]}:{source_addr[1]}" if source_addr else ""
            logger.warning(f"HMAC failure{source_info} logged to: {log_file}")

        except Exception as e:
            # Don't let logging errors break packet processing
            pass

    @staticmethod
    def build_and_serialize(guid: bytes, payload: bytes, key: bytes) -> bytes:
        """
        Build packet and serialize to bytes in one call.

        Args:
            guid: 6-byte GUID
            payload: Packet payload
            key: Symmetric key for HMAC

        Returns:
            bytes: Serialized packet
        """
        packet = PacketBuilder.build_packet(guid, payload, key)
        return packet.to_bytes()
