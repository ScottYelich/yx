# YBS Step: Data Compression

**Step ID:** `ybs-step_h2a0b1c2d3e4`
**Language:** Python
**Prerequisites:** Step g1 complete (Protocol 0 working)

---

## ⚠️ CRITICAL: Do NOT use canonical/ as proof of completion

The `canonical/` directory contains reference files. **DO NOT** look at `canonical/` to confirm work is done.
Verify ONLY by:
1. The file exists at `{{CONFIG:impl_src}}/primitives/data_compression.py`
2. Tests pass when running pytest against the file

Your target directory is `{{CONFIG:impl_src}}` (resolves to `src/yx`).

---

## What This Step Builds

Create `{{CONFIG:impl_src}}/primitives/data_compression.py` — ZLIB compression/decompression utilities.

---

## Implementation

**File:** `{{CONFIG:impl_src}}/primitives/data_compression.py`

```python
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
```

---

## Tests

**File:** `{{CONFIG:impl_src}}/primitives/test_data_compression.py`

```python
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
```

---

## Verification

```bash
pytest {{CONFIG:impl_src}}/primitives/test_data_compression.py -v
```

All 3 tests must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_h2a0b1c2d3e4-DONE.txt`:

```
STEP: ybs-step_h2a0b1c2d3e4
COMPLETED: [ISO 8601 timestamp]
FILES: src/yx/primitives/data_compression.py, test_data_compression.py
VERIFICATION: PASSED
NEXT: ybs-step_h2b0c1d2e3f4
```

Update `BUILD_STATUS.md`: add `- [x] h2a0b1c2d3e4`.
