"""
Data compression utilities using zlib

Provides compression/decompression matching the Swift implementation.
"""

import zlib


def compress_data(data: bytes, level: int = 6) -> bytes:
    """
    Compress data using raw DEFLATE format (matching Apple's COMPRESSION_ZLIB).

    Args:
        data: Data to compress
        level: Compression level (0-9, default: 6)

    Returns:
        bytes: Compressed data in raw DEFLATE format (RFC 1951)
    """
    # Use wbits=-15 to produce raw DEFLATE format (matching Apple's COMPRESSION_ZLIB)
    # The negative value tells zlib to omit the zlib wrapper
    compressor = zlib.compressobj(level=level, wbits=-15)
    compressed = compressor.compress(data)
    compressed += compressor.flush()
    return compressed


def decompress_data(compressed: bytes) -> bytes:
    """
    Decompress zlib-compressed data.

    This function handles both standard zlib format (RFC 1950) and raw DEFLATE format (RFC 1951).
    Apple's COMPRESSION_ZLIB produces raw DEFLATE, so we use wbits=-15 to handle both formats.

    Args:
        compressed: Compressed data

    Returns:
        bytes: Decompressed data

    Raises:
        zlib.error: If decompression fails
    """
    # Use wbits=-15 to handle raw DEFLATE format (used by Apple's COMPRESSION_ZLIB)
    # The negative value tells zlib to expect raw deflate without the zlib wrapper
    return zlib.decompress(compressed, wbits=-15)
