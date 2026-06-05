"""
Data compression utilities using ZLIB.

Traceability:
- specs/architecture/security-architecture.md (Compression)
- specs/technical/yx-protocol-spec.md (ZLIB Compression)
"""

import zlib


def compress_data(data: bytes, level: int = 6) -> bytes:
    """
    Compress data using ZLIB (raw DEFLATE).

    Args:
        data: Data to compress
        level: Compression level 0-9 (6=default, balanced)

    Returns:
        Compressed data

    Traceability:
    - specs/architecture/security-architecture.md (Compression Wire Format)
    - specs/technical/default-values.md (compression_level = 6)

    Note: Uses wbits=-15 for raw DEFLATE (Apple compatibility)
    """
    compressor = zlib.compressobj(level=level, wbits=-15)
    compressed = compressor.compress(data) + compressor.flush()
    return compressed


def decompress_data(compressed: bytes) -> bytes:
    """
    Decompress ZLIB data.

    Args:
        compressed: Compressed data

    Returns:
        Decompressed data

    Traceability:
    - specs/architecture/security-architecture.md (Compression)
    """
    try:
        # Try raw DEFLATE first
        return zlib.decompress(compressed, wbits=-15)
    except zlib.error:
        # Fallback to standard zlib (with header)
        return zlib.decompress(compressed)
