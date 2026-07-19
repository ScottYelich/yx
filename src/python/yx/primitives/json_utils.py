"""
JSON utilities for serialization/deserialization
"""

import json
from typing import Any, Dict, Optional


def json_encode(obj: Any, pretty: bool = False) -> str:
    """
    Encode object to JSON string.

    Args:
        obj: Object to encode
        pretty: Pretty-print with indentation (default: False)

    Returns:
        str: JSON string
    """
    if pretty:
        return json.dumps(obj, indent=2, sort_keys=True)
    return json.dumps(obj, separators=(',', ':'))


def json_decode(json_str: str) -> Any:
    """
    Decode JSON string to object.

    Args:
        json_str: JSON string

    Returns:
        Any: Decoded object

    Raises:
        json.JSONDecodeError: If JSON is invalid
    """
    return json.loads(json_str)


def json_encode_bytes(obj: Any, pretty: bool = False) -> bytes:
    """
    Encode object to JSON bytes (UTF-8).

    Args:
        obj: Object to encode
        pretty: Pretty-print with indentation (default: False)

    Returns:
        bytes: JSON as UTF-8 bytes
    """
    return json_encode(obj, pretty).encode('utf-8')


def json_decode_bytes(json_bytes: bytes) -> Any:
    """
    Decode JSON bytes (UTF-8) to object.

    Args:
        json_bytes: JSON as UTF-8 bytes

    Returns:
        Any: Decoded object

    Raises:
        json.JSONDecodeError: If JSON is invalid
    """
    return json_decode(json_bytes.decode('utf-8'))


def safe_json_get(data: Dict[str, Any], key: str, default: Any = None) -> Any:
    """
    Safely get value from JSON dict with default.

    Args:
        data: JSON dictionary
        key: Key to retrieve
        default: Default value if key not found

    Returns:
        Any: Value or default
    """
    return data.get(key, default)
