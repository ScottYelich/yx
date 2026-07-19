#!/bin/bash
#
# Master test runner for YX interoperability tests.
#
# Full matrix: 48 tests
# - Python->Python (P->P): 12 tests
# - Swift->Swift  (S->S): 12 tests
# - Swift->Python (S->P): 12 tests
# - Python->Swift (P->S): 12 tests
#
# Usage:
#   SWIFT_BUILD_DIR=swift/builds/swift-impl/.build/debug ./tests/interop/run_all_interop_tests.sh
#
# Traceability:
# - protocol/specs/testing/interoperability-requirements.md (48-test matrix)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Locate Python 3 interpreter
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

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TOTAL_PASSED=0
TOTAL_FAILED=0

run_test() {
    local name="$1"
    local cmd="$2"
    echo -n "  $name... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}"
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
    fi
}

echo "========================================"
echo "YX PROTOCOL INTEROPERABILITY TESTS"
echo "========================================"
echo ""

# ------------------------------------------
# PHASE 1: PYTHON→PYTHON (12 tests)
# ------------------------------------------
echo "PHASE 1: Python→Python (12 tests)"
echo "------------------------------------"

echo "Transport layer (5 scenarios):"
run_test "pp_transport_simple"      "$PYTHON transport/test_python_to_python.py --scenario=simple"
run_test "pp_transport_empty"       "$PYTHON transport/test_python_to_python.py --scenario=empty"
run_test "pp_transport_large"       "$PYTHON transport/test_python_to_python.py --scenario=large"
run_test "pp_transport_multiple"    "$PYTHON transport/test_python_to_python.py --scenario=multiple"
run_test "pp_transport_invalid_key" "$PYTHON transport/test_python_to_python.py --scenario=invalid_key"

echo ""
echo "Protocol 0 (3 scenarios):"
run_test "pp_proto0_json"       "$PYTHON protocol0/test_text_protocol.py --scenario=json"
run_test "pp_proto0_large_json" "$PYTHON protocol0/test_text_protocol.py --scenario=large_json"
run_test "pp_proto0_unicode"    "$PYTHON protocol0/test_text_protocol.py --scenario=unicode"

echo ""
echo "Protocol 1 (4 variants):"
run_test "pp_proto1_base"       "$PYTHON protocol1/test_binary_protocol.py --proto-opts=0x00"
run_test "pp_proto1_compressed" "$PYTHON protocol1/test_binary_protocol.py --proto-opts=0x01"
run_test "pp_proto1_encrypted"  "$PYTHON protocol1/test_binary_protocol.py --proto-opts=0x02"
run_test "pp_proto1_both"       "$PYTHON protocol1/test_binary_protocol.py --proto-opts=0x03"

echo ""
echo "Phase 1 result: PASSED=$TOTAL_PASSED FAILED=$TOTAL_FAILED"
echo ""

# ------------------------------------------
# PHASE 2: SWIFT-INVOLVED (36 tests)
# ------------------------------------------
echo "PHASE 2: Swift interop (S→S + S→P + P→S, 36 tests)"
echo "----------------------------------------------------"

SWIFT_TESTS_SCRIPT="$SCRIPT_DIR/swift/run_swift_tests.sh"

if [ ! -f "$SWIFT_TESTS_SCRIPT" ]; then
    echo -e "${RED}ERROR: Swift test script not found: $SWIFT_TESTS_SCRIPT${NC}"
    TOTAL_FAILED=$((TOTAL_FAILED + 36))
else
    chmod +x "$SWIFT_TESTS_SCRIPT"
    SWIFT_OUTPUT=$(PYTHON="$PYTHON" SWIFT_BUILD_DIR="${SWIFT_BUILD_DIR:-swift/builds/swift-impl/.build/debug}" bash "$SWIFT_TESTS_SCRIPT" 2>&1)
    SWIFT_RC=$?
    echo "$SWIFT_OUTPUT"

    # Parse PASSED/FAILED from Swift summary line
    SWIFT_PASSED=$(echo "$SWIFT_OUTPUT" | grep -oE 'PASSED=[0-9]+' | tail -1 | grep -oE '[0-9]+' || echo 0)
    SWIFT_FAILED=$(echo "$SWIFT_OUTPUT" | grep -oE 'FAILED=[0-9]+' | tail -1 | grep -oE '[0-9]+' || echo 0)

    TOTAL_PASSED=$((TOTAL_PASSED + SWIFT_PASSED))
    TOTAL_FAILED=$((TOTAL_FAILED + SWIFT_FAILED))
fi

echo ""

# ------------------------------------------
# FINAL SUMMARY
# ------------------------------------------
echo "========================================"
echo "FINAL SUMMARY"
echo "========================================"
echo -e "Passed:  ${GREEN}${TOTAL_PASSED}${NC}"
echo -e "Failed:  ${RED}${TOTAL_FAILED}${NC}"
echo "Total:   $((TOTAL_PASSED + TOTAL_FAILED)) / 48"
echo "========================================"

if [ "$TOTAL_FAILED" -eq 0 ] && [ "$TOTAL_PASSED" -eq 48 ]; then
    echo -e "${GREEN}ALL 48 INTEROP TESTS PASSED — YX SYSTEM COMPLETE${NC}"
    exit 0
elif [ "$TOTAL_FAILED" -eq 0 ]; then
    echo -e "${YELLOW}All tests passed but count mismatch: $TOTAL_PASSED/48${NC}"
    exit 1
else
    echo -e "${RED}${TOTAL_FAILED} test(s) FAILED — $TOTAL_PASSED/48 passed${NC}"
    exit 1
fi
