# YBS Step: GUID Hex Utility (extend guid_factory.py)

**Step ID:** `ybs-step_i3d0e1f2a3b4`
**Language:** Python
**Prerequisites:** Step i3c complete (key_store.py exists)

---

## ⚠️ CRITICAL: Do NOT use canonical/ as proof of completion

The `canonical/` directory contains reference files. **DO NOT** look at `canonical/` to confirm work is done.
Verify ONLY by:
1. `guid_to_hex` function exists in `{{CONFIG:impl_src}}/primitives/guid_factory.py`
2. Test passes when running pytest

Your target directory is `{{CONFIG:impl_src}}` (resolves to `src/yx`).

---

## What This Step Builds

**Extend** `{{CONFIG:impl_src}}/primitives/guid_factory.py` — add `guid_to_hex()` standalone function.

The file already exists with the `GUIDFactory` class. Add ONE new standalone function at the bottom.

---

## Add to bottom of `{{CONFIG:impl_src}}/primitives/guid_factory.py`

```python
def guid_to_hex(guid: bytes) -> str:
    """
    Convert GUID bytes to uppercase hex string.

    Args:
        guid: 6-byte GUID

    Returns:
        Uppercase hex string (e.g., "E32E3CA702DE")

    Traceability:
    - protocol/specs/architecture/api-contracts.md (Type Conversion Utilities)
    """
    return guid.hex().upper()
```

---

## Test

**Add** this test to `{{CONFIG:impl_src}}/primitives/test_guid_factory.py` (existing file — APPEND):

```python
from yx.primitives.guid_factory import guid_to_hex


def test_guid_to_hex():
    guid = bytes([0xE3, 0x2E, 0x3C, 0xA7, 0x02, 0xDE])
    assert guid_to_hex(guid) == "E32E3CA702DE"
    assert guid_to_hex(b'\x00' * 6) == "000000000000"
```

---

## Verification

```bash
pytest {{CONFIG:impl_src}}/primitives/test_guid_factory.py -v -k "guid_to_hex"
```

Test must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_i3d0e1f2a3b4-DONE.txt`:

```
STEP: ybs-step_i3d0e1f2a3b4
COMPLETED: [ISO 8601 timestamp]
FILES: src/yx/primitives/guid_factory.py (extended), test_guid_factory.py (extended)
VERIFICATION: PASSED
NEXT: ybs-step_j4a0b1c2d3e4
```

Update `BUILD_STATUS.md`: add `- [x] i3d0e1f2a3b4`.
