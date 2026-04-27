#!/bin/bash
#
# Swift interoperability test runner
# Tests Swift sender/receiver programs against Python and Swift implementations
#
# Traceability:
# - specs/testing/interoperability-requirements.md (Standalone Test Suite)
# - steps/swift/ybs-step_k5l6m7n8o9p0.md (Step 15)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0
FAILED_TESTS=()

# Swift executable paths
SWIFT_BUILD_DIR="swift/.build/debug"

# Ensure Swift executables are built
if [ ! -d "$SWIFT_BUILD_DIR" ]; then
    echo "Building Swift interop programs..."
    cd swift && swift build && cd ..
fi

run_test() {
    local test_name="$1"
    local sender="$2"
    local receiver="$3"
    local timeout=${4:-10}

    echo -n "  Testing: $test_name... "

    # Start receiver in background
    timeout $timeout $receiver > /tmp/receiver.log 2>&1 &
    local receiver_pid=$!

    # Give receiver time to bind
    sleep 0.5

    # Run sender
    if timeout $timeout $sender > /tmp/sender.log 2>&1; then
        # Wait briefly for receiver to process
        sleep 0.5

        # Check if receiver succeeded
        if wait $receiver_pid 2>/dev/null; then
            echo -e "${GREEN}PASS${NC}"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}FAIL${NC} (receiver failed)"
            ((FAILED++))
            FAILED_TESTS+=("$test_name")
            return 1
        fi
    else
        echo -e "${RED}FAIL${NC} (sender failed)"
        ((FAILED++))
        FAILED_TESTS+=("$test_name")
        kill $receiver_pid 2>/dev/null || true
        return 1
    fi
}

echo "========================================"
echo "YX SWIFT INTEROPERABILITY TESTS"
echo "========================================"
echo ""

# ============================================
# TRANSPORT LAYER TESTS
# ============================================

echo "========================================"
echo "PART 1: TRANSPORT LAYER (UDP + HMAC)"
echo "========================================"
echo ""

echo -e "${BLUE}Test 1: Swift → Swift (Transport)${NC}"
run_test "Transport/Swift→Swift/Simple" \
    "$SWIFT_BUILD_DIR/swift-sender-transport-simple" \
    "$SWIFT_BUILD_DIR/swift-receiver-transport"

run_test "Transport/Swift→Swift/Empty" \
    "$SWIFT_BUILD_DIR/swift-sender-transport-empty" \
    "$SWIFT_BUILD_DIR/swift-receiver-transport"

run_test "Transport/Swift→Swift/Large" \
    "$SWIFT_BUILD_DIR/swift-sender-transport-large" \
    "$SWIFT_BUILD_DIR/swift-receiver-transport"

run_test "Transport/Swift→Swift/Multiple" \
    "$SWIFT_BUILD_DIR/swift-sender-transport-multiple" \
    "$SWIFT_BUILD_DIR/swift-receiver-transport"

# Invalid test - receiver should reject, so this is expected to fail
echo -n "  Testing: Transport/Swift→Swift/Invalid... "
if run_test "Transport/Swift→Swift/Invalid-internal" \
    "$SWIFT_BUILD_DIR/swift-sender-transport-invalid" \
    "$SWIFT_BUILD_DIR/swift-receiver-transport" > /dev/null 2>&1; then
    # If it passed, that's wrong - invalid HMAC should be rejected
    echo -e "${RED}FAIL${NC} (invalid HMAC was accepted)"
    ((FAILED++))
    FAILED_TESTS+=("Transport/Swift→Swift/Invalid")
else
    # Receiver correctly rejected invalid HMAC
    echo -e "${GREEN}PASS${NC} (correctly rejected)"
    ((PASSED++))
fi

echo ""

# ============================================
# PROTOCOL 0 (TEXT) TESTS
# ============================================

echo "========================================"
echo "PART 2: PROTOCOL 0 (TEXT/JSON-RPC)"
echo "========================================"
echo ""

echo -e "${BLUE}Test 2: Swift → Swift (Proto0)${NC}"
run_test "Proto0/Swift→Swift/JSON" \
    "$SWIFT_BUILD_DIR/swift-sender-proto0-json" \
    "$SWIFT_BUILD_DIR/swift-receiver-proto0"

run_test "Proto0/Swift→Swift/Large" \
    "$SWIFT_BUILD_DIR/swift-sender-proto0-large" \
    "$SWIFT_BUILD_DIR/swift-receiver-proto0"

# Invalid test - receiver should reject invalid JSON
echo -n "  Testing: Proto0/Swift→Swift/Invalid... "
if run_test "Proto0/Swift→Swift/Invalid-internal" \
    "$SWIFT_BUILD_DIR/swift-sender-proto0-invalid" \
    "$SWIFT_BUILD_DIR/swift-receiver-proto0" > /dev/null 2>&1; then
    echo -e "${RED}FAIL${NC} (invalid JSON was accepted)"
    ((FAILED++))
    FAILED_TESTS+=("Proto0/Swift→Swift/Invalid")
else
    echo -e "${GREEN}PASS${NC} (correctly rejected)"
    ((PASSED++))
fi

echo ""

# ============================================
# PROTOCOL 1 (BINARY) TESTS
# ============================================

echo "========================================"
echo "PART 3: PROTOCOL 1 (BINARY/CHUNKED)"
echo "========================================"
echo ""

echo -e "${BLUE}Test 3: Swift → Swift (Proto1)${NC}"
run_test "Proto1/Swift→Swift/Base" \
    "$SWIFT_BUILD_DIR/swift-sender-proto1-base" \
    "$SWIFT_BUILD_DIR/swift-receiver-proto1"

run_test "Proto1/Swift→Swift/Compressed" \
    "$SWIFT_BUILD_DIR/swift-sender-proto1-compressed" \
    "$SWIFT_BUILD_DIR/swift-receiver-proto1"

run_test "Proto1/Swift→Swift/Encrypted" \
    "$SWIFT_BUILD_DIR/swift-sender-proto1-encrypted" \
    "$SWIFT_BUILD_DIR/swift-receiver-proto1"

run_test "Proto1/Swift→Swift/Both" \
    "$SWIFT_BUILD_DIR/swift-sender-proto1-both" \
    "$SWIFT_BUILD_DIR/swift-receiver-proto1"

echo ""

# ============================================
# SUMMARY
# ============================================

echo "========================================"
echo "Results: $PASSED passed, $FAILED failed (out of 12 Swift→Swift tests)"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}FAILED TESTS:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done
    echo ""
    echo "See /tmp/sender.log and /tmp/receiver.log for details"
    exit 1
else
    echo -e "${GREEN}ALL SWIFT TESTS PASSED!${NC}"
    echo ""
    echo "Note: This tests Swift→Swift only."
    echo "For full 48-test matrix (Python↔Swift interop), see run_all_interop_tests.sh"
    exit 0
fi
