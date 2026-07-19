"""
Data compression utilities using ZLIB.

Traceability:
- protocol/specs/architecture/security-architecture.md (Compression)
- protocol/specs/technical/yx-protocol-spec.md (ZLIB Compression)
- protocol/specs/technical/default-values.md (compression_level = 6)
"""

import zlib


def compress_data(data: bytes, level: int = 6) -> bytes:
    """
    Compress data using ZLIB raw DEFLATE (wbits=-15).

    Args:
        data: Data to compress
        level: Compression level 0-9 (default: 6)

    Returns:
        Compressed bytes

    Traceability:
    - protocol/specs/architecture/security-architecture.md (Compression Wire Format)

    Note: Uses wbits=-15 for raw DEFLATE (cross-platform compatibility).
    """
    compressor = zlib.compressobj(level=level, wbits=-15)
    return compressor.compress(data) + compressor.flush()


def decompress_data(compressed: bytes) -> bytes:
    """
    Decompress ZLIB data (raw DEFLATE).

    Args:
        compressed: Compressed bytes

    Returns:
        Decompressed bytes

    Traceability:
    - protocol/specs/architecture/security-architecture.md (Compression)
    """
    try:
        return zlib.decompress(compressed, wbits=-15)
    except zlib.error:
        return zlib.decompress(compressed)
