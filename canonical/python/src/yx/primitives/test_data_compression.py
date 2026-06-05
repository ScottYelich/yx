"""Tests for data compression."""

import pytest
from yx.primitives.data_compression import compress_data, decompress_data


def test_compress_decompress_roundtrip():
    """Test compression/decompression roundtrip."""
    original = b"Hello, World!" * 100
    compressed = compress_data(original)
    decompressed = decompress_data(compressed)

    assert decompressed == original
    assert len(compressed) < len(original)  # Should be smaller


def test_compress_incompressible_data():
    """Test compression on random data."""
    import os
    random_data = os.urandom(1000)

    compressed = compress_data(random_data)
    decompressed = decompress_data(compressed)

    assert decompressed == random_data


def test_compress_empty_data():
    """Test compression on empty data."""
    compressed = compress_data(b"")
    decompressed = decompress_data(compressed)

    assert decompressed == b""
