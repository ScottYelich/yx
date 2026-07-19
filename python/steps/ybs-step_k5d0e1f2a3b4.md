# YBS Step: Master Interop Test Runner

**Step ID:** `ybs-step_k5d0e1f2a3b4`
**Language:** Python
**Prerequisites:** Step k5c complete (all individual test scripts exist and pass)

---

## ⚠️ CRITICAL: Do NOT use canonical/ as proof of completion

The `canonical/` directory contains reference files. **DO NOT** look at `canonical/` to confirm work is done.
Verify ONLY by:
1. `tests/interop/run_all_interop_tests.sh` exists and is executable
2. Running it shows Python-to-Python tests passing

---

## What This Step Builds

Create `tests/interop/run_all_interop_tests.sh` — master runner for the full 48-test matrix.

Also create `tests/interop/README.md` documenting the test structure.

---

## File 1: `tests/interop/run_all_interop_tests.sh`

```bash
#!/bin/bash
#
# Master test runner for YX interoperability tests.
#
# Full matrix: 48 tests
# - Transport (Python→Python, P→S, S→P, S→S): 20 tests
# - Protocol 0 (Text): 12 tests
# - Protocol 1 (Binary): 16 tests
#
# Traceability:
# - protocol/specs/testing/interoperability-requirements.md

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

run_test() {
    local name="$1"
    local cmd="$2"
    echo -n "  $name... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}"
        FAILED=$((FAILED + 1))
    fi
}

echo "========================================"
echo "YX PROTOCOL INTEROPERABILITY TESTS"
echo "========================================"
echo ""

# ──────────────────────────────────────────
# PART 1: TRANSPORT LAYER (20 tests target)
# ──────────────────────────────────────────
echo "PART 1: TRANSPORT LAYER (UDP + HMAC)"
echo "────────────────────────────────────"
echo "Python → Python (5 scenarios):"
run_test "simple"       "python transport/test_python_to_python.py --scenario=simple"
run_test "empty"        "python transport/test_python_to_python.py --scenario=empty"
run_test "large"        "python transport/test_python_to_python.py --scenario=large"
run_test "multiple"     "python transport/test_python_to_python.py --scenario=multiple"
run_test "invalid_key"  "python transport/test_python_to_python.py --scenario=invalid_key"
echo ""
echo "Python → Swift: (requires Swift build)"
echo "Swift → Python: (requires Swift build)"
echo "Swift → Swift:  (requires Swift build)"
echo ""

# ──────────────────────────────────────────
# PART 2: PROTOCOL 0 (12 tests target)
# ──────────────────────────────────────────
echo "PART 2: PROTOCOL 0 (TEXT/JSON-RPC)"
echo "────────────────────────────────────"
echo "Python → Python (3 scenarios):"
run_test "json"         "python protocol0/test_text_protocol.py --scenario=json"
run_test "large_json"   "python protocol0/test_text_protocol.py --scenario=large_json"
run_test "unicode"      "python protocol0/test_text_protocol.py --scenario=unicode"
echo ""
echo "Python → Swift: (requires Swift build)"
echo "Swift → Python: (requires Swift build)"
echo "Swift → Swift:  (requires Swift build)"
echo ""

# ──────────────────────────────────────────
# PART 3: PROTOCOL 1 (16 tests target)
# ──────────────────────────────────────────
echo "PART 3: PROTOCOL 1 (BINARY/CHUNKED)"
echo "────────────────────────────────────"
echo "Python → Python (4 variants):"
run_test "base (0x00)"  "python protocol1/test_binary_protocol.py --proto-opts=0x00"
run_test "compressed"   "python protocol1/test_binary_protocol.py --proto-opts=0x01"
run_test "encrypted"    "python protocol1/test_binary_protocol.py --proto-opts=0x02"
run_test "both (0x03)"  "python protocol1/test_binary_protocol.py --proto-opts=0x03"
echo ""
echo "Python → Swift: (requires Swift build)"
echo "Swift → Python: (requires Swift build)"
echo "Swift → Swift:  (requires Swift build)"
echo ""

# ──────────────────────────────────────────
# SUMMARY
# ──────────────────────────────────────────
echo "========================================"
echo "SUMMARY"
echo "========================================"
echo -e "Passed:  ${GREEN}${PASSED}${NC}"
echo -e "Failed:  ${RED}${FAILED}${NC}"
echo "Total:   $((PASSED + FAILED)) (Python-only phase)"
echo "Target:  48 (after Swift build)"
echo "========================================"

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✅ All Python-phase tests PASSED${NC}"
    exit 0
else
    echo -e "${RED}❌ ${FAILED} test(s) FAILED${NC}"
    exit 1
fi
```

---

## File 2: `tests/interop/README.md`

```markdown
# YX Interoperability Tests

## Test Matrix (48 total)

| Layer | P→P | P→S | S→P | S→S | Scenarios | Tests |
|-------|-----|-----|-----|-----|-----------|-------|
| Transport | ✅ | 🔄 | 🔄 | 🔄 | 5 | 20 |
| Protocol 0 | ✅ | 🔄 | 🔄 | 🔄 | 3 | 12 |
| Protocol 1 | ✅ | 🔄 | 🔄 | 🔄 | 4 | 16 |

✅ = Python build complete | 🔄 = Requires Swift build

## Running Tests

```bash
cd tests/interop
./run_all_interop_tests.sh
```

## Directory Structure

```
tests/interop/
├── run_all_interop_tests.sh    # Master runner
├── senders/                     # Sender programs
│   ├── python_sender_proto0.py
│   ├── python_sender_proto1_base.py
│   ├── python_sender_proto1_compressed.py
│   ├── python_sender_proto1_encrypted.py
│   └── python_sender_proto1_both.py
├── receivers/                   # Receiver programs
│   ├── python_receiver_proto0.py
│   └── python_receiver_proto1.py
├── transport/                   # Transport tests
│   └── test_python_to_python.py
├── protocol0/                   # Protocol 0 tests
│   └── test_text_protocol.py
└── protocol1/                   # Protocol 1 tests
    └── test_binary_protocol.py
```
```

---

## Verification

```bash
chmod +x tests/interop/run_all_interop_tests.sh
cd tests/interop
./run_all_interop_tests.sh
```

Expected: 12 Python-phase tests pass, FAILED=0, exit code 0.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_k5d0e1f2a3b4-DONE.txt`:

```
STEP: ybs-step_k5d0e1f2a3b4
COMPLETED: [ISO 8601 timestamp]
FILES: tests/interop/run_all_interop_tests.sh, tests/interop/README.md
VERIFICATION: PASSED (12/12 Python tests, 0 failures)
NEXT: Python implementation COMPLETE — proceed to Swift build
```

Update `BUILD_STATUS.md`: add `- [x] k5d0e1f2a3b4` and set Progress to 26/26 (100%).
