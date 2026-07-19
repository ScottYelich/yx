# YBS Step: Swift Interop Test Scripts

**Step ID:** `ybs-step_sw5c0d1e2f3a`
**Language:** Swift
**Prerequisites:** Step sw5b complete (SwiftReceiver/main.swift exists and builds)

---

## What This Step Builds

Create Swift-involved interop test scripts in `tests/interop/`:
- Swift→Swift (S→S): 12 tests
- Swift→Python (S→P): 12 tests  
- Python→Swift (P→S): 12 tests

Together with the Python→Python tests from k5c (12 tests), this completes the 48-test matrix.

---

## ⚠️ CRITICAL PATH REQUIREMENTS

The test scripts MUST use absolute paths or rely on environment variables for binary locations:

```bash
SWIFT_BUILD="${SWIFT_BUILD_DIR:-.build/debug}"
SWIFT_SENDER="$SWIFT_BUILD/SwiftSender"
SWIFT_RECEIVER="$SWIFT_BUILD/SwiftReceiver"
PYTHON_SENDER_DIR="tests/interop/senders"
PYTHON_RECEIVER_DIR="tests/interop/receivers"
```

All scripts are run from the `yx/` project root.

---

## File: `tests/interop/swift/run_swift_tests.sh`

```bash
#!/usr/bin/env bash
# Swift interop tests: S→S, S→P, P→S
# Run from yx/ project root.
# Usage: SWIFT_BUILD_DIR=swift/builds/swift-impl/.build/debug ./tests/interop/swift/run_swift_tests.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$PROJECT_ROOT"

SWIFT_BUILD="${SWIFT_BUILD_DIR:-.build/debug}"
SWIFT_SENDER="$SWIFT_BUILD/SwiftSender"
SWIFT_RECEIVER="$SWIFT_BUILD/SwiftReceiver"
PYTHON_SENDER_DIR="tests/interop/senders"
PYTHON_RECEIVER_DIR="tests/interop/receivers"
TEST_PORT="${TEST_YX_PORT:-49999}"

PASSED=0
FAILED=0

run_test() {
    local name="$1"
    local cmd="$2"
    if eval "$cmd" >/dev/null 2>&1; then
        echo "PASS: $name"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL: $name"
        FAILED=$((FAILED + 1))
    fi
}

# ── S→S Transport Tests ──────────────────────────────────────────────────────

run_ss_transport() {
    local mode="$1"
    local name="$2"
    # Start receiver in background
    TEST_YX_PORT=$TEST_PORT "$SWIFT_RECEIVER" proto0 3 &
    RECV_PID=$!
    sleep 0.2
    # Run sender
    TEST_YX_PORT=$TEST_PORT "$SWIFT_SENDER" "$mode"
    local rc=$?
    wait $RECV_PID 2>/dev/null || true
    return $rc
}

run_test "ss_transport_proto0"       "run_ss_transport proto0"
run_test "ss_transport_proto1_base"  "run_ss_transport proto1-base"
run_test "ss_transport_proto1_comp"  "run_ss_transport proto1-compressed"
run_test "ss_transport_proto1_enc"   "run_ss_transport proto1-encrypted"
run_test "ss_transport_proto1_both"  "run_ss_transport proto1-both"

# ── S→S Protocol 0 Tests ─────────────────────────────────────────────────────

run_ss_proto0() {
    local json="$1"
    TEST_YX_PORT=$TEST_PORT "$SWIFT_RECEIVER" proto0 3 &
    RECV_PID=$!
    sleep 0.2
    TEST_YX_PORT=$TEST_PORT "$SWIFT_SENDER" proto0 "$json"
    local rc=$?
    wait $RECV_PID 2>/dev/null || true
    return $rc
}

run_test "ss_proto0_basic"    "run_ss_proto0 '{\"method\":\"ping\"}'"
run_test "ss_proto0_method"   "run_ss_proto0 '{\"method\":\"test\",\"id\":1}'"
run_test "ss_proto0_unicode"  "run_ss_proto0 '{\"msg\":\"hello\"}'"

# ── S→S Protocol 1 Tests ─────────────────────────────────────────────────────

run_ss_proto1() {
    local mode="$1"
    TEST_YX_PORT=$TEST_PORT "$SWIFT_RECEIVER" proto1 5 &
    RECV_PID=$!
    sleep 0.2
    TEST_YX_PORT=$TEST_PORT "$SWIFT_SENDER" "$mode"
    local rc=$?
    wait $RECV_PID 2>/dev/null || true
    return $rc
}

run_test "ss_proto1_base"       "run_ss_proto1 proto1-base"
run_test "ss_proto1_compressed" "run_ss_proto1 proto1-compressed"
run_test "ss_proto1_encrypted"  "run_ss_proto1 proto1-encrypted"
run_test "ss_proto1_both"       "run_ss_proto1 proto1-both"

# ── S→P Transport Tests ──────────────────────────────────────────────────────

run_sp_transport() {
    local mode="$1"
    local recv_script="$2"
    TEST_YX_PORT=$TEST_PORT python3 "$PYTHON_RECEIVER_DIR/$recv_script" &
    RECV_PID=$!
    sleep 0.3
    TEST_YX_PORT=$TEST_PORT "$SWIFT_SENDER" "$mode"
    local rc=$?
    wait $RECV_PID 2>/dev/null || true
    return $rc
}

run_test "sp_transport_proto0"      "run_sp_transport proto0      python_receiver_proto0.py"
run_test "sp_transport_proto1_base" "run_sp_transport proto1-base  python_receiver_proto1.py"
run_test "sp_transport_proto1_comp" "run_sp_transport proto1-compressed python_receiver_proto1.py"
run_test "sp_transport_proto1_enc"  "run_sp_transport proto1-encrypted  python_receiver_proto1.py"
run_test "sp_transport_proto1_both" "run_sp_transport proto1-both  python_receiver_proto1.py"

# ── S→P Protocol 0 Tests ─────────────────────────────────────────────────────

run_sp_proto0() {
    local json="$1"
    TEST_YX_PORT=$TEST_PORT python3 "$PYTHON_RECEIVER_DIR/python_receiver_proto0.py" &
    RECV_PID=$!
    sleep 0.3
    TEST_YX_PORT=$TEST_PORT "$SWIFT_SENDER" proto0 "$json"
    local rc=$?
    wait $RECV_PID 2>/dev/null || true
    return $rc
}

run_test "sp_proto0_basic"   "run_sp_proto0 '{\"method\":\"ping\"}'"
run_test "sp_proto0_method"  "run_sp_proto0 '{\"method\":\"test\",\"id\":1}'"
run_test "sp_proto0_unicode" "run_sp_proto0 '{\"msg\":\"hello\"}'"

# ── S→P Protocol 1 Tests ─────────────────────────────────────────────────────

run_sp_proto1() {
    local mode="$1"
    TEST_YX_PORT=$TEST_PORT python3 "$PYTHON_RECEIVER_DIR/python_receiver_proto1.py" &
    RECV_PID=$!
    sleep 0.3
    TEST_YX_PORT=$TEST_PORT "$SWIFT_SENDER" "$mode"
    local rc=$?
    wait $RECV_PID 2>/dev/null || true
    return $rc
}

run_test "sp_proto1_base"       "run_sp_proto1 proto1-base"
run_test "sp_proto1_compressed" "run_sp_proto1 proto1-compressed"
run_test "sp_proto1_encrypted"  "run_sp_proto1 proto1-encrypted"
run_test "sp_proto1_both"       "run_sp_proto1 proto1-both"

# ── P→S Transport Tests ──────────────────────────────────────────────────────

run_ps_transport() {
    local mode="$1"
    local recv_mode="$2"
    TEST_YX_PORT=$TEST_PORT "$SWIFT_RECEIVER" "$recv_mode" 5 &
    RECV_PID=$!
    sleep 0.2
    TEST_YX_PORT=$TEST_PORT python3 "$PYTHON_SENDER_DIR/python_sender_$mode.py"
    local rc=$?
    wait $RECV_PID 2>/dev/null || true
    return $rc
}

run_test "ps_transport_proto0"      "run_ps_transport proto0      proto0"
run_test "ps_transport_proto1_base" "run_ps_transport proto1_base  proto1"
run_test "ps_transport_proto1_comp" "run_ps_transport proto1_compressed proto1"
run_test "ps_transport_proto1_enc"  "run_ps_transport proto1_encrypted  proto1"
run_test "ps_transport_proto1_both" "run_ps_transport proto1_both  proto1"

# ── P→S Protocol 0 Tests ─────────────────────────────────────────────────────

run_ps_proto0() {
    local sender="$1"
    TEST_YX_PORT=$TEST_PORT "$SWIFT_RECEIVER" proto0 5 &
    RECV_PID=$!
    sleep 0.2
    TEST_YX_PORT=$TEST_PORT python3 "$PYTHON_SENDER_DIR/$sender"
    local rc=$?
    wait $RECV_PID 2>/dev/null || true
    return $rc
}

run_test "ps_proto0_basic"   "run_ps_proto0 python_sender_proto0.py"
run_test "ps_proto0_method"  "run_ps_proto0 python_sender_proto0.py"
run_test "ps_proto0_unicode" "run_ps_proto0 python_sender_proto0.py"

# ── P→S Protocol 1 Tests ─────────────────────────────────────────────────────

run_ps_proto1() {
    local sender="$1"
    TEST_YX_PORT=$TEST_PORT "$SWIFT_RECEIVER" proto1 5 &
    RECV_PID=$!
    sleep 0.2
    TEST_YX_PORT=$TEST_PORT python3 "$PYTHON_SENDER_DIR/$sender"
    local rc=$?
    wait $RECV_PID 2>/dev/null || true
    return $rc
}

run_test "ps_proto1_base"       "run_ps_proto1 python_sender_proto1_base.py"
run_test "ps_proto1_compressed" "run_ps_proto1 python_sender_proto1_compressed.py"
run_test "ps_proto1_encrypted"  "run_ps_proto1 python_sender_proto1_encrypted.py"
run_test "ps_proto1_both"       "run_ps_proto1 python_sender_proto1_both.py"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "Swift interop: PASSED=$PASSED FAILED=$FAILED"
[ $FAILED -eq 0 ] && exit 0 || exit 1
```

---

## Verification

```bash
chmod +x tests/interop/swift/run_swift_tests.sh
SWIFT_BUILD_DIR={{CONFIG:swift_build_dir}}/.build/debug \
    bash tests/interop/swift/run_swift_tests.sh 2>&1 | tail -5
```

Final line must be `Swift interop: PASSED=36 FAILED=0` and exit code 0.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_sw5c0d1e2f3a-DONE.txt`:

```
STEP: ybs-step_sw5c0d1e2f3a
COMPLETED: [ISO 8601 timestamp]
FILES: tests/interop/swift/run_swift_tests.sh
VERIFICATION: PASSED (36/36 swift interop tests pass)
NEXT: ybs-step_sw5d0e1f2a3b
```

Update `BUILD_STATUS.md`: add `- [x] sw5c0d1e2f3a`.
