"""Test compression functions"""

from yx.primitives.data_compression import compress_data, decompress_data


def test_compress():
    """Test data compression"""
    data = b"test data " * 100  # Repeating data compresses well
    compressed = compress_data(data)
    assert len(compressed) < len(data)


def test_decompress():
    """Test data decompression"""
    data = b"test data " * 100
    compressed = compress_data(data)
    decompressed = decompress_data(compressed)
    assert decompressed == data


def test_compress_small():
    """Test compression of small data"""
    data = b"small"
    compressed = compress_data(data)
    # Small data might not compress well
    decompressed = decompress_data(compressed)
    assert decompressed == data


def test_compress_round_trip():
    """Test compression round trip"""
    original = b"The quick brown fox jumps over the lazy dog. " * 50
    compressed = compress_data(original)
    decompressed = decompress_data(compressed)
    assert decompressed == original
    assert len(compressed) < len(original)
