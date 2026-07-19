# YBS Step: Data Chunking

**Step ID:** `ybs-step_h2b0c1d2e3f4`
**Language:** Python
**Prerequisites:** Step h2a complete (data_compression.py exists)

---

## ⚠️ CRITICAL: Do NOT use canonical/ as proof of completion

The `canonical/` directory contains reference files. **DO NOT** look at `canonical/` to confirm work is done.
Verify ONLY by:
1. The file exists at `{{CONFIG:impl_src}}/primitives/data_chunking.py`
2. Tests pass when running pytest against the file

Your target directory is `{{CONFIG:impl_src}}` (resolves to `src/yx`).

---

## What This Step Builds

Create `{{CONFIG:impl_src}}/primitives/data_chunking.py` — split data into fixed-size chunks and reassemble.

---

## Implementation

**File:** `{{CONFIG:impl_src}}/primitives/data_chunking.py`

```python
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
```

---

## Tests

**File:** `{{CONFIG:impl_src}}/primitives/test_data_chunking.py`

```python
"""Tests for data chunking."""

import pytest
from yx.primitives.data_chunking import chunk_data, unchunk_data


def test_chunk_unchunk_roundtrip():
    original = b"A" * 5000
    chunks = chunk_data(original, chunk_size=1024)
    assert unchunk_data(chunks) == original
    assert len(chunks) == 5


def test_chunk_small_data():
    data = b"Small"
    chunks = chunk_data(data, chunk_size=1024)
    assert len(chunks) == 1
    assert chunks[0] == data


def test_chunk_empty_data():
    chunks = chunk_data(b"", chunk_size=1024)
    assert len(chunks) == 1
    assert chunks[0] == b""


def test_chunk_exact_multiple():
    data = b"X" * 2048
    chunks = chunk_data(data, chunk_size=1024)
    assert len(chunks) == 2
```

---

## Verification

```bash
pytest {{CONFIG:impl_src}}/primitives/test_data_chunking.py -v
```

All 4 tests must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_h2b0c1d2e3f4-DONE.txt`:

```
STEP: ybs-step_h2b0c1d2e3f4
COMPLETED: [ISO 8601 timestamp]
FILES: src/yx/primitives/data_chunking.py, test_data_chunking.py
VERIFICATION: PASSED
NEXT: ybs-step_h2c0d1e2f3a4
```

Update `BUILD_STATUS.md`: add `- [x] h2b0c1d2e3f4`.
