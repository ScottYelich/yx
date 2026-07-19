"""Tests for data compression."""

import pytest
import os
from yx.primitives.data_compression import compress_data, decompress_data


def test_compress_decompress_roundtrip():
    original = b"Hello, World!" * 100
    compressed = compress_data(original)
    assert decompress_data(compressed) == original
    assert len(compressed) < len(original)


def test_compress_incompressible():
    data = os.urandom(1000)
    assert decompress_data(compress_data(data)) == data


def test_compress_empty():
    assert decompress_data(compress_data(b"")) == b""
