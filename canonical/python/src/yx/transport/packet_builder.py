"""
Packet Builder - Construct YX packets with HMAC.

Implements: specs/technical/yx-protocol-spec.md § Packet Building/Parsing Logic
"""

from typing import Optional
from .packet import Packet
from ..primitives import GUIDFactory, compute_packet_hmac, validate_packet_hmac


class PacketBuilder:
    """Build YX protocol packets with HMAC computation."""

    @staticmethod
    def build_packet(guid: bytes, payload: bytes, key: bytes) -> Packet:
        """
        Build a complete YX packet with HMAC.

        Args:
            guid: Sender GUID (will be padded to 6 bytes)
            payload: Packet payload
            key: 32-byte symmetric key

        Returns:
            Packet: Complete packet with HMAC

        Example:
            >>> key = b'\\x00' * 32
            >>> guid = b'\\x01' * 6
            >>> payload = b'test'
            >>> packet = PacketBuilder.build_packet(guid, payload, key)
            >>> len(packet.hmac)
            16
        """
        # Pad GUID to exactly 6 bytes
        padded_guid = GUIDFactory.pad_guid(guid)

        # Compute HMAC over GUID + Payload
        hmac_value = compute_packet_hmac(padded_guid, payload, key)

        # Create and return packet
        return Packet(hmac=hmac_value, guid=padded_guid, payload=payload)

    @staticmethod
    def build_and_serialize(guid: bytes, payload: bytes, key: bytes) -> bytes:
        """
        Build packet and serialize to wire format in one step.

        Args:
            guid: Sender GUID
            payload: Packet payload
            key: 32-byte symmetric key

        Returns:
            bytes: Serialized packet (HMAC + GUID + Payload)

        Example:
            >>> key = b'\\x00' * 32
            >>> data = PacketBuilder.build_and_serialize(b'\\x01'*6, b'test', key)
            >>> len(data)
            26
        """
        packet = PacketBuilder.build_packet(guid, payload, key)
        return packet.to_bytes()

    @staticmethod
    def parse_packet(data: bytes) -> Optional[Packet]:
        """
        Parse packet from wire format (no validation).

        Args:
            data: Raw packet bytes (minimum 22 bytes)

        Returns:
            Packet if parseable, None otherwise
        """
        return Packet.from_bytes(data)

    @staticmethod
    def validate_hmac(packet: Packet, key: bytes) -> bool:
        """
        Validate packet HMAC.

        Args:
            packet: Packet to validate
            key: 32-byte symmetric key

        Returns:
            bool: True if HMAC is valid
        """
        return validate_packet_hmac(packet.guid, packet.payload, key, packet.hmac)

    @staticmethod
    def parse_and_validate(data: bytes, key: bytes) -> Optional[Packet]:
        """
        Parse packet and validate HMAC.

        Args:
            data: Raw packet bytes
            key: 32-byte symmetric key

        Returns:
            Packet if valid, None if invalid/corrupted

        Example:
            >>> key = b'\\x00' * 32
            >>> data = PacketBuilder.build_and_serialize(b'\\x01'*6, b'test', key)
            >>> packet = PacketBuilder.parse_and_validate(data, key)
            >>> packet.payload
            b'test'
        """
        packet = PacketBuilder.parse_packet(data)
        if packet is None:
            return None

        if not PacketBuilder.validate_hmac(packet, key):
            return None

        return packet
