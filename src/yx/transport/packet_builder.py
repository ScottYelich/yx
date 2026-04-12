"""
Packet Builder - Construct YX packets with HMAC.

Implements: protocol/specs/technical/yx-protocol-spec.md § Packet Building/Parsing Logic
"""

from typing import Optional
from .packet import Packet
from ..primitives import GUIDFactory, compute_packet_hmac


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
            >>> key = b'\x00' * 32
            >>> guid = b'\x01' * 6
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
            >>> key = b'\x00' * 32
            >>> data = PacketBuilder.build_and_serialize(b'\x01'*6, b'test', key)
            >>> len(data)
            26
        """
        packet = PacketBuilder.build_packet(guid, payload, key)
        return packet.to_bytes()
