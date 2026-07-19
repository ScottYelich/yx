"""
Data chunking utilities.

Traceability:
- protocol/specs/architecture/protocol-layers.md (Chunking)
- protocol/specs/technical/yx-protocol-spec.md (Chunking Algorithm)
- protocol/specs/technical/default-values.md (chunk_size = 1024)
"""

from typing import List


def chunk_data(data: bytes, chunk_size: int = 1024) -> List[bytes]:
    """
    Split data into fixed-size chunks.

    Args:
        data: Data to split
        chunk_size: Maximum size per chunk (default: 1024)

    Returns:
        List of byte chunks (at least one, even for empty data)

    Traceability:
    - protocol/specs/technical/default-values.md (chunk_size = 1024)
    """
    if chunk_size <= 0:
        raise ValueError("chunk_size must be positive")

    if not data:
        return [b""]

    chunks = []
    for i in range(0, len(data), chunk_size):
        chunks.append(data[i:i + chunk_size])
    return chunks


def unchunk_data(chunks: List[bytes]) -> bytes:
    """
    Reassemble chunks into original data.

    Args:
        chunks: Ordered list of chunks

    Returns:
        Reassembled bytes

    Traceability:
    - protocol/specs/architecture/protocol-layers.md (Reassembly Algorithm)
    """
    return b"".join(chunks)
