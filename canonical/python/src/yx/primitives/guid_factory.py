"""
GUID Factory - Generate 6-byte sender identifiers.

Implements: specs/technical/yx-protocol-spec.md § Layer 2: GUID
"""

import os
from typing import Optional


class GUIDFactory:
    """Factory for generating and managing 6-byte GUIDs."""

    @staticmethod
    def generate() -> bytes:
        """
        Generate a new 6-byte GUID using cryptographically secure random bytes.

        Returns:
            bytes: 6 random bytes

        Example:
            >>> guid = GUIDFactory.generate()
            >>> len(guid)
            6
        """
        return os.urandom(6)

    @staticmethod
    def pad_guid(guid: bytes) -> bytes:
        """
        Pad a GUID to exactly 6 bytes with zero bytes.

        If GUID is longer than 6 bytes, truncate to 6 bytes.
        If GUID is shorter than 6 bytes, pad with zeros.

        Args:
            guid: Input bytes (any length)

        Returns:
            bytes: Exactly 6 bytes

        Example:
            >>> GUIDFactory.pad_guid(b'\\x01\\x02')
            b'\\x01\\x02\\x00\\x00\\x00\\x00'
            >>> GUIDFactory.pad_guid(b'\\x01\\x02\\x03\\x04\\x05\\x06\\x07\\x08')
            b'\\x01\\x02\\x03\\x04\\x05\\x06'
        """
        if len(guid) == 6:
            return guid
        elif len(guid) < 6:
            # Pad with zeros
            return guid + b'\x00' * (6 - len(guid))
        else:
            # Truncate to 6 bytes
            return guid[:6]

    @staticmethod
    def from_hex(hex_string: str) -> bytes:
        """
        Create GUID from hexadecimal string.

        Args:
            hex_string: Hex string (e.g., "010203040506")

        Returns:
            bytes: 6-byte GUID (padded if necessary)

        Raises:
            ValueError: If hex string is invalid

        Example:
            >>> GUIDFactory.from_hex("010203040506")
            b'\\x01\\x02\\x03\\x04\\x05\\x06'
        """
        guid_bytes = bytes.fromhex(hex_string)
        return GUIDFactory.pad_guid(guid_bytes)

    @staticmethod
    def to_hex(guid: bytes) -> str:
        """
        Convert GUID to hexadecimal string.

        Args:
            guid: 6-byte GUID

        Returns:
            str: Hex string (e.g., "010203040506")

        Example:
            >>> GUIDFactory.to_hex(b'\\x01\\x02\\x03\\x04\\x05\\x06')
            '010203040506'
        """
        return guid.hex()
