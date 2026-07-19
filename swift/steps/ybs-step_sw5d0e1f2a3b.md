# YBS Step: Master Interop Runner (All 48 Tests)

**Step ID:** `ybs-step_sw5d0e1f2a3b`
**Language:** Swift
**Prerequisites:** Step sw5c complete (Swift interop test scripts exist)

---

## What This Step Builds

Update `tests/interop/run_all_interop_tests.sh` to run all 48 tests:
- 12 Python→Python tests (from Python k5d step)
- 36 Swift-involved tests (from Swift sw5c step: S→S, S→P, P→S)

**Total: 48 tests. ALL must pass.**

---

## ⚠️ CRITICAL REQUIREMENT

Do NOT overwrite the existing `run_all_interop_tests.sh` from the Python build.
**APPEND** the Swift section and update the summary line.

If the file does not yet exist, create it from scratch with both sections.

---

## Complete File: `tests/interop/run_all_interop_tests.sh`

Replace/create the entire file with:

```bash
#!/usr/bin/env bash
# Master interop test runner — all 48 tests
# Tests: 12 P→P + 12 S→S + 12 S→P + 12 P→S = 48
# Run from yx/ project root.
#
# Usage:
#   SWIFT_BUILD_DIR=swift/builds/swift-impl/.build/debug ./tests/interop/run_all_interop_tests.sh
#
# Traceability:
#   - protocol/specs/testing/interoperability-requirements.md (48-test matrix)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

TOTAL_PASSED=0
TOTAL_FAILED=0
FAILED_TESTS=()

run_section() {
    local name="$1"
    local script="$2"
    local env_prefix="${3:-}"

    echo ""
    echo "════════════════════════════════════════"
    echo " $name"
    echo "════════════════════════════════════════"

    local output
    local rc=0
    if [ -n "$env_prefix" ]; then
        output=$(eval "$env_prefix bash $script 2>&1") || rc=$?
    else
        output=$(bash "$script" 2>&1) || rc=$?
    fi

    echo "$output"

    # Parse PASSED/FAILED from summary line
    local passed failed
    passed=$(echo "$output" | grep -oE 'PASSED=[0-9]+' | tail -1 | grep -oE '[0-9]+' || echo 0)
    failed=$(echo "$output" | grep -oE 'FAILED=[0-9]+' | tail -1 | grep -oE '[0-9]+' || echo 0)

    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))

    if [ "$failed" -gt 0 ]; then
        FAILED_TESTS+=("$name ($failed failures)")
    fi
}

# ── Phase 1: Python→Python (12 tests) ───────────────────────────────────────
run_section "Python→Python Transport (5)" \
    "tests/interop/transport/test_python_python_transport.sh"

run_section "Python→Python Protocol 0 (3)" \
    "tests/interop/protocol0/test_python_python_proto0.sh"

run_section "Python→Python Protocol 1 (4)" \
    "tests/interop/protocol1/test_python_python_proto1.sh"

# ── Phase 2: Swift-involved (36 tests) ───────────────────────────────────────
SWIFT_BUILD_ENV="SWIFT_BUILD_DIR=${SWIFT_BUILD_DIR:-swift/builds/swift-impl/.build/debug}"

run_section "Swift Interop (S→S + S→P + P→S, 36 tests)" \
    "tests/interop/swift/run_swift_tests.sh" \
    "$SWIFT_BUILD_ENV"

# ── Final Summary ─────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo " FINAL RESULT"
echo "════════════════════════════════════════"
echo "Total: PASSED=$TOTAL_PASSED FAILED=$TOTAL_FAILED (of 48)"

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo ""
    echo "Failed sections:"
    for t in "${FAILED_TESTS[@]}"; do
        echo "  - $t"
    done
fi

echo ""
if [ "$TOTAL_FAILED" -eq 0 ] && [ "$TOTAL_PASSED" -eq 48 ]; then
    echo "✓ ALL 48 INTEROP TESTS PASSED — YX SYSTEM COMPLETE"
    exit 0
else
    echo "✗ INTEROP TESTS INCOMPLETE: $TOTAL_PASSED/48 passed"
    exit 1
fi
```

---

## Verification

```bash
chmod +x tests/interop/run_all_interop_tests.sh
SWIFT_BUILD_DIR={{CONFIG:swift_build_dir}}/.build/debug \
    bash tests/interop/run_all_interop_tests.sh 2>&1 | tail -10
```

Final output must include:
```
Total: PASSED=48 FAILED=0 (of 48)
ALL 48 INTEROP TESTS PASSED — YX SYSTEM COMPLETE
```
Exit code must be 0.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_sw5d0e1f2a3b-DONE.txt`:

```
STEP: ybs-step_sw5d0e1f2a3b
COMPLETED: [ISO 8601 timestamp]
FILES: tests/interop/run_all_interop_tests.sh
VERIFICATION: PASSED (48/48 interop tests pass)
NEXT: BUILD COMPLETE
```

Update `BUILD_STATUS.md`: add `- [x] sw5d0e1f2a3b`.
