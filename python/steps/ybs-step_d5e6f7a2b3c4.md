# Step 10: Generate Canonical Artifacts

**Version**: 0.1.0

## Overview

Generate canonical test vectors and reference packets that other language implementations will validate against.

## What This Step Builds

Generates canonical test vectors — authoritative JSON files in `canonical/test-vectors/` that encode known inputs, expected HMAC values, and expected packet bytes for cross-language validation by Swift and future implementations.

## Step Objectives

1. Generate text protocol test vectors
2. Generate binary protocol test vectors (future)
3. Generate reference packets
4. Export to canonical/ directory

## Prerequisites

- Step 9 completed (all tests passing)

## Traceability

**Implements**: Canonical Artifacts workflow

## Instructions

### Before Starting — Record Start Time

Record the current timestamp in ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`
This is used for duration calculation in the DONE file.

### 1. Create Canonical Generator

Create `tests/generate_canonical.py`:

```python
"""Generate canonical test vectors for cross-implementation validation."""

import json
from pathlib import Path
from yx.transport import PacketBuilder
from yx.primitives import GUIDFactory


def generate_test_vectors():
    """Generate JSON test vectors."""
    vectors = {
        "version": "1.0.0",
        "protocol": "YX UDP Protocol",
        "test_cases": []
    }

    # Test case 1: Simple packet
    key = b'\\x00' * 32
    guid = b'\\x01' * 6
    payload = b'test payload'

    packet = PacketBuilder.build_packet(guid, payload, key)
    data = packet.to_bytes()

    vectors["test_cases"].append({
        "name": "Simple text payload",
        "guid": guid.hex(),
        "key": key.hex(),
        "payload": payload.decode('ascii'),
        "payload_hex": payload.hex(),
        "expected_hmac": packet.hmac.hex(),
        "expected_packet": data.hex(),
    })

    # Test case 2: Empty payload
    payload2 = b''
    packet2 = PacketBuilder.build_packet(guid, payload2, key)
    data2 = packet2.to_bytes()

    vectors["test_cases"].append({
        "name": "Empty payload",
        "guid": guid.hex(),
        "key": key.hex(),
        "payload": "",
        "payload_hex": "",
        "expected_hmac": packet2.hmac.hex(),
        "expected_packet": data2.hex(),
    })

    # Test case 3: Large payload
    payload3 = b'X' * 1000
    packet3 = PacketBuilder.build_packet(guid, payload3, key)
    data3 = packet3.to_bytes()

    vectors["test_cases"].append({
        "name": "Large payload (1000 bytes)",
        "guid": guid.hex(),
        "key": key.hex(),
        "payload_hex": payload3.hex(),
        "expected_hmac": packet3.hmac.hex(),
        "expected_packet": data3.hex(),
    })

    return vectors


def main():
    """Generate and save canonical artifacts."""
    # Ensure canonical directory exists
    canonical_dir = Path("../../canonical/test-vectors")
    canonical_dir.mkdir(parents=True, exist_ok=True)

    # Generate test vectors
    vectors = generate_test_vectors()

    # Save to JSON
    output_file = canonical_dir / "text-protocol-packets.json"
    with open(output_file, 'w') as f:
        json.dump(vectors, f, indent=2)

    print(f"✓ Generated {len(vectors['test_cases'])} test vectors")
    print(f"✓ Saved to {output_file}")


if __name__ == "__main__":
    main()
```

### 2. Run Generator

```bash
cd builds/python-impl
python3 tests/generate_canonical.py
```

### 3. Verify Canonical Artifacts

```bash
# Verify file exists
test -f ../../canonical/test-vectors/text-protocol-packets.json && echo "✓ Canonical artifacts generated"

# Verify JSON is valid
python3 -m json.tool ../../canonical/test-vectors/text-protocol-packets.json > /dev/null && echo "✓ JSON is valid"

# Count test cases
python3 -c "import json; data = json.load(open('../../canonical/test-vectors/text-protocol-packets.json')); print(f'✓ {len(data[\"test_cases\"])} test cases generated')"
```

## Verification

- [ ] Canonical artifacts generated
- [ ] JSON is valid
- [ ] At least 3 test cases
- [ ] Files in ../../canonical/test-vectors/

```bash
cd builds/python-impl
python3 tests/generate_canonical.py
ls -lh ../../canonical/test-vectors/
```

## Notes

- Python generates canonical artifacts (reference implementation)
- Swift will validate against these artifacts
- This ensures wire format compatibility
- Test vectors enable cross-language validation

## Documentation

**Record end time** and calculate duration (end − start timestamp).

Create `docs/build-history/ybs-step_d5e6f7a2b3c4-DONE.txt`:

```
STEP ybs-step_d5e6f7a2b3c4: Generate Canonical Artifacts
STARTED:    [start timestamp from Before Starting]
COMPLETED:  [ISO 8601 timestamp]
DURATION:   [minutes]

OBJECTIVES COMPLETED:
[copy from Step Objectives above]

FILES CREATED/MODIFIED:
- tests/generate_canonical.py
- ../../canonical/test-vectors/hmac-test-vectors.json
- ../../canonical/test-vectors/text-protocol-packets.json

VERIFICATION: PASSED (attempt [N])

NEXT STEP: ybs-step_g1h2i3j4k5l6 (Protocol 0 (Text/JSON-RPC))
```

Update `BUILD_STATUS.md`: mark this step `[x]` and update **Last Updated** timestamp.

## Success Criteria

This step is successful when:
1. All verification checks pass (within 3 attempts)
2. All required files exist and are valid
3. Build compiles/runs without errors
4. DONE file created in `docs/build-history/`
5. `BUILD_STATUS.md` updated

## Next Steps

After completing this step, proceed to:
- **Next**: `ybs-step_g1h2i3j4k5l6` — Protocol 0 (Text/JSON-RPC)

## Version History

### 0.1.0 (2026-04-11)
- Initial step creation
