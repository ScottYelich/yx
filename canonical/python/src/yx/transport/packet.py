"""
Packet Data Structure - In-memory representation of YX packets.

Implements: specs/technical/yx-protocol-spec.md § Wire Format
"""

from dataclasses import dataclass
from typing import Optional


@dataclass
class Packet:
    """
    YX Protocol Packet.

    Wire format:
        HMAC (16 bytes) + GUID (6 bytes) + Payload (variable)

    Minimum packet size: 22 bytes (16 + 6 + 0)
    """

    hmac: bytes      # 16 bytes
    guid: bytes      # 6 bytes
    payload: bytes   # Variable length

    def __post_init__(self):
        """Validate packet fields."""
        if not isinstance(self.hmac, bytes):
            raise TypeError(f"hmac must be bytes, got {type(self.hmac)}")
        if not isinstance(self.guid, bytes):
            raise TypeError(f"guid must be bytes, got {type(self.guid)}")
        if not isinstance(self.payload, bytes):
            raise TypeError(f"payload must be bytes, got {type(self.payload)}")

        if len(self.hmac) != 16:
            raise ValueError(f"hmac must be 16 bytes, got {len(self.hmac)}")
        if len(self.guid) != 6:
            raise ValueError(f"guid must be 6 bytes, got {len(self.guid)}")

    def to_bytes(self) -> bytes:
        """
        Serialize packet to wire format.

        Returns:
            bytes: HMAC(16) + GUID(6) + Payload(N)

        Example:
            >>> packet = Packet(b'\\x00'*16, b'\\x01'*6, b'test')
            >>> data = packet.to_bytes()
            >>> len(data)
            26
        """
        return self.hmac + self.guid + self.payload

    @classmethod
    def from_bytes(cls, data: bytes) -> Optional["Packet"]:
        """
        Deserialize packet from wire format.

        Args:
            data: Raw packet bytes (minimum 22 bytes)

        Returns:
            Packet if valid, None if invalid

        Example:
            >>> data = b'\\x00'*16 + b'\\x01'*6 + b'test'
            >>> packet = Packet.from_bytes(data)
            >>> packet.payload
            b'test'
        """
        if len(data) < 22:
            return None

        try:
            hmac = data[0:16]
            guid = data[16:22]
            payload = data[22:]
            return cls(hmac=hmac, guid=guid, payload=payload)
        except (TypeError, ValueError):
            return None

    def __len__(self) -> int:
        """Return total packet size in bytes."""
        return 16 + 6 + len(self.payload)

    def __repr__(self) -> str:
        """Return string representation."""
        return (
            f"Packet(hmac={self.hmac.hex()[:8]}..., "
            f"guid={self.guid.hex()}, "
            f"payload={len(self.payload)}B)"
        )
