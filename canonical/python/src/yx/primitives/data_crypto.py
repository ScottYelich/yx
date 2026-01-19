"""
Data Cryptography Primitives - HMAC, AES-GCM, etc.

Implements: specs/technical/yx-protocol-spec.md § Security Mechanisms
"""

import hmac as hmac_module
from cryptography.hazmat.primitives import hashes, hmac


def compute_hmac(data: bytes, key: bytes, truncate_to: int = 16) -> bytes:
    """
    Compute HMAC-SHA256 and truncate to specified length.

    Args:
        data: Data to compute HMAC over
        key: 32-byte symmetric key
        truncate_to: Output length in bytes (default: 16)

    Returns:
        bytes: Truncated HMAC

    Raises:
        ValueError: If key is not 32 bytes
        ValueError: If truncate_to > 32

    Example:
        >>> key = b'\\x00' * 32
        >>> data = b'test data'
        >>> mac = compute_hmac(data, key, truncate_to=16)
        >>> len(mac)
        16
    """
    if len(key) != 32:
        raise ValueError(f"Key must be 32 bytes, got {len(key)}")
    if truncate_to > 32:
        raise ValueError(f"Cannot truncate to more than 32 bytes, got {truncate_to}")

    h = hmac.HMAC(key, hashes.SHA256())
    h.update(data)
    mac = h.finalize()
    return mac[:truncate_to]


def validate_hmac_constant_time(
    data: bytes,
    key: bytes,
    expected_hmac: bytes,
    truncate_to: int = 16
) -> bool:
    """
    Validate HMAC using constant-time comparison.

    Args:
        data: Data to validate
        key: 32-byte symmetric key
        expected_hmac: Expected HMAC value
        truncate_to: HMAC length in bytes (default: 16)

    Returns:
        bool: True if HMAC is valid, False otherwise

    Example:
        >>> key = b'\\x00' * 32
        >>> data = b'test'
        >>> mac = compute_hmac(data, key)
        >>> validate_hmac_constant_time(data, key, mac)
        True
    """
    try:
        computed_hmac = compute_hmac(data, key, truncate_to)
        # Use constant-time comparison to prevent timing attacks
        return hmac_module.compare_digest(computed_hmac, expected_hmac)
    except (ValueError, TypeError):
        return False


def compute_packet_hmac(guid: bytes, payload: bytes, key: bytes) -> bytes:
    """
    Compute HMAC for YX packet (GUID + Payload).

    Args:
        guid: 6-byte sender GUID
        payload: Packet payload bytes
        key: 32-byte symmetric key

    Returns:
        bytes: 16-byte HMAC

    Example:
        >>> key = b'\\x00' * 32
        >>> guid = b'\\x01' * 6
        >>> payload = b'test'
        >>> mac = compute_packet_hmac(guid, payload, key)
        >>> len(mac)
        16
    """
    if len(guid) != 6:
        raise ValueError(f"GUID must be 6 bytes, got {len(guid)}")

    hmac_input = guid + payload
    return compute_hmac(hmac_input, key, truncate_to=16)


def validate_packet_hmac(
    guid: bytes,
    payload: bytes,
    key: bytes,
    expected_hmac: bytes
) -> bool:
    """
    Validate HMAC for YX packet.

    Args:
        guid: 6-byte sender GUID
        payload: Packet payload bytes
        key: 32-byte symmetric key
        expected_hmac: Expected 16-byte HMAC

    Returns:
        bool: True if valid, False otherwise

    Example:
        >>> key = b'\\x00' * 32
        >>> guid = b'\\x01' * 6
        >>> payload = b'test'
        >>> mac = compute_packet_hmac(guid, payload, key)
        >>> validate_packet_hmac(guid, payload, key, mac)
        True
    """
    try:
        computed_hmac = compute_packet_hmac(guid, payload, key)
        return hmac_module.compare_digest(computed_hmac, expected_hmac)
    except (ValueError, TypeError):
        return False
