#!/usr/bin/env bash
# Swift interop tests: S→S, S→P, P→S (36 tests total)
# Run from yx/ project root.
# Usage: SWIFT_BUILD_DIR=swift/builds/swift-impl/.build/debug ./tests/interop/swift/run_swift_tests.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$PROJECT_ROOT"

SWIFT_BUILD="${SWIFT_BUILD_DIR:-swift/builds/swift-impl/.build/debug}"
SWIFT_SENDER="$SWIFT_BUILD/SwiftSender"
SWIFT_RECEIVER="$SWIFT_BUILD/SwiftReceiver"
PYTHON_SENDER_DIR="tests/interop/senders"
PYTHON_RECEIVER_DIR="tests/interop/receivers"
TEST_PORT="${TEST_YX_PORT:-49999}"

# Locate Python interpreter
PYTHON="${PYTHON:-}"
if [ -z "$PYTHON" ]; then
    for candidate in /Users/scottyelich/.pyenv/versions/3.12.8/bin/python python3.12 python3 python; do
        if command -v "$candidate" > /dev/null 2>&1 && "$candidate" -c "import sys; sys.exit(0 if sys.version_info >= (3,8) else 1)" 2>/dev/null; then
            PYTHON="$candidate"
            break
        fi
    done
fi
if [ -z "$PYTHON" ]; then
    echo "ERROR: No suitable Python 3.8+ interpreter found"
    exit 1
fi

# Verify Swift binaries exist
if [ ! -x "$SWIFT_SENDER" ]; then
    echo "ERROR: SwiftSender not found at $SWIFT_SENDER"
    echo "Run: cd swift/builds/swift-impl && swift build"
    exit 1
fi
if [ ! -x "$SWIFT_RECEIVER" ]; then
    echo "ERROR: SwiftReceiver not found at $SWIFT_RECEIVER"
    echo "Run: cd swift/builds/swift-impl && swift build"
    exit 1
fi

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

# ── S→S Transport Tests (5) ───────────────────────────────────────────────────

run_ss_transport() {
    local mode="$1"
    TEST_YX_PORT=$TEST_PORT "$SWIFT_RECEIVER" proto0 3 &
    local recv_pid=$!
    sleep 0.2
    TEST_YX_PORT=$TEST_PORT "$SWIFT_SENDER" "$mode"
    local rc=$?
    wait $recv_pid 2>/dev/null || true
    return $rc
}

run_test "ss_transport_proto0"      "run_ss_transport proto0"
run_test "ss_transport_proto1_base" "run_ss_transport proto1-base"
run_test "ss_transport_proto1_comp" "run_ss_transport proto1-compressed"
run_test "ss_transport_proto1_enc"  "run_ss_transport proto1-encrypted"
run_test "ss_transport_proto1_both" "run_ss_transport proto1-both"

# ── S→S Protocol 0 Tests (3) ─────────────────────────────────────────────────

run_ss_proto0() {
    local json="$1"
    TEST_YX_PORT=$TEST_PORT "$SWIFT_RECEIVER" proto0 3 &
    local recv_pid=$!
    sleep 0.2
    TEST_YX_PORT=$TEST_PORT "$SWIFT_SENDER" proto0 "$json"
    local rc=$?
    wait $recv_pid 2>/dev/null || true
    return $rc
}

run_test "ss_proto0_basic"   "run_ss_proto0 '{\"method\":\"ping\"}'"
run_test "ss_proto0_method"  "run_ss_proto0 '{\"method\":\"test\",\"id\":1}'"
run_test "ss_proto0_unicode" "run_ss_proto0 '{\"msg\":\"hello\"}'"

# ── S→S Protocol 1 Tests (4) ─────────────────────────────────────────────────

run_ss_proto1() {
    local mode="$1"
    TEST_YX_PORT=$TEST_PORT "$SWIFT_RECEIVER" proto1 5 &
    local recv_pid=$!
    sleep 0.2
    TEST_YX_PORT=$TEST_PORT "$SWIFT_SENDER" "$mode"
    local rc=$?
    wait $recv_pid 2>/dev/null || true
    return $rc
}

run_test "ss_proto1_base"       "run_ss_proto1 proto1-base"
run_test "ss_proto1_compressed" "run_ss_proto1 proto1-compressed"
run_test "ss_proto1_encrypted"  "run_ss_proto1 proto1-encrypted"
run_test "ss_proto1_both"       "run_ss_proto1 proto1-both"

# ── S→P Transport Tests (5) ──────────────────────────────────────────────────

run_sp_transport() {
    local mode="$1"
    local recv_script="$2"
    TEST_YX_PORT=$TEST_PORT "$PYTHON" "$PYTHON_RECEIVER_DIR/$recv_script" &
    local recv_pid=$!
    sleep 0.3
    TEST_YX_PORT=$TEST_PORT "$SWIFT_SENDER" "$mode"
    local rc=$?
    wait $recv_pid 2>/dev/null || true
    return $rc
}

run_test "sp_transport_proto0"      "run_sp_transport proto0           python_receiver_proto0.py"
run_test "sp_transport_proto1_base" "run_sp_transport proto1-base       python_receiver_proto1.py"
run_test "sp_transport_proto1_comp" "run_sp_transport proto1-compressed python_receiver_proto1.py"
run_test "sp_transport_proto1_enc"  "run_sp_transport proto1-encrypted  python_receiver_proto1.py"
run_test "sp_transport_proto1_both" "run_sp_transport proto1-both       python_receiver_proto1.py"

# ── S→P Protocol 0 Tests (3) ─────────────────────────────────────────────────

run_sp_proto0() {
    local json="$1"
    TEST_YX_PORT=$TEST_PORT "$PYTHON" "$PYTHON_RECEIVER_DIR/python_receiver_proto0.py" &
    local recv_pid=$!
    sleep 0.3
    TEST_YX_PORT=$TEST_PORT "$SWIFT_SENDER" proto0 "$json"
    local rc=$?
    wait $recv_pid 2>/dev/null || true
    return $rc
}

run_test "sp_proto0_basic"   "run_sp_proto0 '{\"method\":\"ping\"}'"
run_test "sp_proto0_method"  "run_sp_proto0 '{\"method\":\"test\",\"id\":1}'"
run_test "sp_proto0_unicode" "run_sp_proto0 '{\"msg\":\"hello\"}'"

# ── S→P Protocol 1 Tests (4) ─────────────────────────────────────────────────

run_sp_proto1() {
    local mode="$1"
    TEST_YX_PORT=$TEST_PORT "$PYTHON" "$PYTHON_RECEIVER_DIR/python_receiver_proto1.py" &
    local recv_pid=$!
    sleep 0.3
    TEST_YX_PORT=$TEST_PORT "$SWIFT_SENDER" "$mode"
    local rc=$?
    wait $recv_pid 2>/dev/null || true
    return $rc
}

run_test "sp_proto1_base"       "run_sp_proto1 proto1-base"
run_test "sp_proto1_compressed" "run_sp_proto1 proto1-compressed"
run_test "sp_proto1_encrypted"  "run_sp_proto1 proto1-encrypted"
run_test "sp_proto1_both"       "run_sp_proto1 proto1-both"

# ── P→S Transport Tests (5) ──────────────────────────────────────────────────

run_ps_transport() {
    local sender_suffix="$1"
    local recv_mode="$2"
    TEST_YX_PORT=$TEST_PORT "$SWIFT_RECEIVER" "$recv_mode" 5 &
    local recv_pid=$!
    sleep 0.2
    TEST_YX_PORT=$TEST_PORT "$PYTHON" "$PYTHON_SENDER_DIR/python_sender_${sender_suffix}.py"
    local rc=$?
    wait $recv_pid 2>/dev/null || true
    return $rc
}

run_test "ps_transport_proto0"      "run_ps_transport proto0           proto0"
run_test "ps_transport_proto1_base" "run_ps_transport proto1_base       proto1"
run_test "ps_transport_proto1_comp" "run_ps_transport proto1_compressed proto1"
run_test "ps_transport_proto1_enc"  "run_ps_transport proto1_encrypted  proto1"
run_test "ps_transport_proto1_both" "run_ps_transport proto1_both       proto1"

# ── P→S Protocol 0 Tests (3) ─────────────────────────────────────────────────

run_ps_proto0() {
    local sender="$1"
    TEST_YX_PORT=$TEST_PORT "$SWIFT_RECEIVER" proto0 5 &
    local recv_pid=$!
    sleep 0.2
    TEST_YX_PORT=$TEST_PORT "$PYTHON" "$PYTHON_SENDER_DIR/$sender"
    local rc=$?
    wait $recv_pid 2>/dev/null || true
    return $rc
}

run_test "ps_proto0_basic"   "run_ps_proto0 python_sender_proto0.py"
run_test "ps_proto0_method"  "run_ps_proto0 python_sender_proto0.py"
run_test "ps_proto0_unicode" "run_ps_proto0 python_sender_proto0.py"

# ── P→S Protocol 1 Tests (4) ─────────────────────────────────────────────────

run_ps_proto1() {
    local sender="$1"
    TEST_YX_PORT=$TEST_PORT "$SWIFT_RECEIVER" proto1 5 &
    local recv_pid=$!
    sleep 0.2
    TEST_YX_PORT=$TEST_PORT "$PYTHON" "$PYTHON_SENDER_DIR/$sender"
    local rc=$?
    wait $recv_pid 2>/dev/null || true
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
