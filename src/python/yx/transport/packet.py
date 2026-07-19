"""
Packet data structure

Represents the 3-layer packet structure: HMAC + GUID + Payload
"""

from dataclasses import dataclass
from typing import Optional


@dataclass
class Packet:
    """
    UDP packet structure matching Swift implementation.

    Layout: [HMAC(16)] + [GUID(6)] + [Payload(variable)]
    Minimum size: 22 bytes
    """

    hmac: bytes  # 16 bytes
    guid: bytes  # 6 bytes (padded)
    payload: bytes  # Variable length

    def __post_init__(self):
        """Validate packet structure"""
        if len(self.hmac) != 16:
            raise ValueError(f"HMAC must be exactly 16 bytes, got {len(self.hmac)}")
        if len(self.guid) != 6:
            raise ValueError(f"GUID must be exactly 6 bytes, got {len(self.guid)}")

    def to_bytes(self) -> bytes:
        """
        Serialize packet to bytes.

        Returns:
            bytes: Packet as bytes
        """
        return self.hmac + self.guid + self.payload

    @classmethod
    def from_bytes(cls, data: bytes) -> Optional['Packet']:
        """
        Parse packet from bytes.

        Args:
            data: Raw packet bytes

        Returns:
            Optional[Packet]: Parsed packet, or None if invalid
        """
        if len(data) < 22:  # Minimum: 16 (HMAC) + 6 (GUID)
            return None

        hmac = data[0:16]
        guid = data[16:22]
        payload = data[22:]

        try:
            return cls(hmac=hmac, guid=guid, payload=payload)
        except ValueError:
            return None

    def __len__(self) -> int:
        """Return total packet size in bytes"""
        return 16 + 6 + len(self.payload)
