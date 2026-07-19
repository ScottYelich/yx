"""
Data chunking utilities for splitting and reassembling data

Used by Protocol 1 for handling large payloads.
"""

from typing import List


def chunk_data(data: bytes, chunk_size: int = 1024) -> List[bytes]:
    """
    Split data into fixed-size chunks.

    Args:
        data: Data to chunk
        chunk_size: Maximum size of each chunk (default: 1024 bytes)

    Returns:
        List[bytes]: List of chunks
    """
    if not data:
        return []

    chunks = []
    offset = 0
    while offset < len(data):
        chunk = data[offset:offset + chunk_size]
        chunks.append(chunk)
        offset += chunk_size

    return chunks


def unchunk_data(chunks: List[bytes]) -> bytes:
    """
    Reassemble chunks into original data.

    Args:
        chunks: List of data chunks

    Returns:
        bytes: Reassembled data
    """
    return b''.join(chunks)
