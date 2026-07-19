"""
GUID generation and encoding utilities

Provides 6-byte GUID generation matching the Swift implementation.
"""

import secrets
from typing import Union


class GUIDFactory:
    """Factory for generating secure 6-byte GUIDs"""

    @staticmethod
    def generate() -> bytes:
        """
        Generate a secure random 6-byte GUID.

        Returns:
            bytes: 6 random bytes
        """
        return secrets.token_bytes(6)

    @staticmethod
    def pad_guid(guid: bytes) -> bytes:
        """
        Pad GUID to exactly 6 bytes with zero padding.

        Args:
            guid: GUID bytes (may be shorter than 6 bytes)

        Returns:
            bytes: 6-byte padded GUID
        """
        if len(guid) >= 6:
            return guid[:6]
        return guid + b'\x00' * (6 - len(guid))


def guid_to_hex(guid: bytes) -> str:
    """
    Convert GUID bytes to hex string.

    Args:
        guid: GUID bytes

    Returns:
        str: Hex string (uppercase, no separators)
    """
    return guid.hex().upper()


def hex_to_guid(hex_string: str) -> bytes:
    """
    Convert hex string to GUID bytes.

    Args:
        hex_string: Hex string (with or without separators)

    Returns:
        bytes: GUID bytes
    """
    # Remove common separators
    hex_clean = hex_string.replace(':', '').replace('-', '').replace(' ', '')
    return bytes.fromhex(hex_clean)
