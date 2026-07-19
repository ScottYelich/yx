"""
Hexadecimal encoding utilities
"""


def bytes_to_hex(data: bytes, uppercase: bool = True) -> str:
    """
    Convert bytes to hexadecimal string.

    Args:
        data: Bytes to convert
        uppercase: Use uppercase hex digits (default: True)

    Returns:
        str: Hexadecimal string
    """
    hex_str = data.hex()
    return hex_str.upper() if uppercase else hex_str


def hex_to_bytes(hex_string: str) -> bytes:
    """
    Convert hexadecimal string to bytes.

    Args:
        hex_string: Hex string (with or without separators like : or -)

    Returns:
        bytes: Decoded bytes
    """
    # Remove common separators
    hex_clean = hex_string.replace(':', '').replace('-', '').replace(' ', '')
    return bytes.fromhex(hex_clean)
