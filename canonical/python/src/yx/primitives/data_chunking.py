"""
Data chunking utilities.

Traceability:
- specs/architecture/protocol-layers.md (Chunking)
- specs/technical/yx-protocol-spec.md (Chunking Algorithm)
"""

from typing import List


def chunk_data(data: bytes, chunk_size: int = 1024) -> List[bytes]:
    """
    Split data into fixed-size chunks.

    Args:
        data: Data to chunk
        chunk_size: Size of each chunk in bytes (default: 1024)

    Returns:
        List of chunks

    Traceability:
    - specs/technical/default-values.md (chunk_size = 1024)
    """
    if chunk_size <= 0:
        raise ValueError("Chunk size must be positive")

    chunks = []
    for i in range(0, len(data), chunk_size):
        chunk = data[i:i + chunk_size]
        chunks.append(chunk)

    return chunks if chunks else [b""]  # At least one chunk (empty)


def unchunk_data(chunks: List[bytes]) -> bytes:
    """
    Reassemble chunks into original data.

    Args:
        chunks: List of chunks (dict keys are indices)

    Returns:
        Reassembled data

    Traceability:
    - specs/architecture/protocol-layers.md (Reassembly Algorithm)
    """
    return b"".join(chunks)
