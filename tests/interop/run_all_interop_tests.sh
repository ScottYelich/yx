#!/bin/bash
#
# Master test runner for YX interoperability tests.
#
# Runs all 48 mandatory tests:
# - Transport layer: 20 tests
# - Protocol 0: 12 tests
# - Protocol 1: 16 tests
#
# Traceability:
# - specs/testing/interoperability-requirements.md (Standalone Test Suite)

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

run_test() {
    local test_name="$1"
    local test_command="$2"

    echo -n "  Testing: $test_name... "

    if eval "timeout 10 $test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}"
        ((FAILED++))
    fi

    # Wait briefly between tests to avoid port conflicts
    sleep 0.2
}

echo "========================================"
echo "YX PROTOCOL INTEROPERABILITY TESTS"
echo "========================================"
echo ""

# PART 1: TRANSPORT LAYER TESTS (20 tests)
echo "========================================"
echo "PART 1: TRANSPORT LAYER (UDP + HMAC)"
echo "========================================"
echo ""

# Python → Python (5 scenarios)
echo -e "${BLUE}Test 1/4: Python → Python${NC}"
run_test "Simple payload" "python3 transport/test_python_to_python.py --scenario=simple"
run_test "Empty payload" "python3 transport/test_python_to_python.py --scenario=empty"
run_test "Large payload" "python3 transport/test_python_to_python.py --scenario=large"
run_test "Multiple packets" "python3 transport/test_python_to_python.py --scenario=multiple"
run_test "Invalid key" "python3 transport/test_python_to_python.py --scenario=invalid_key"
echo ""

# Python → Swift (5 scenarios) - TODO after Swift implementation
echo -e "${YELLOW}Test 2/4: Python → Swift (requires Swift implementation)${NC}"
echo ""

# Swift → Python (5 scenarios) - TODO after Swift implementation
echo -e "${YELLOW}Test 3/4: Swift → Python (requires Swift implementation)${NC}"
echo ""

# Swift → Swift (5 scenarios) - TODO after Swift implementation
echo -e "${YELLOW}Test 4/4: Swift → Swift (requires Swift implementation)${NC}"
echo ""

TRANSPORT_PASSED=$PASSED
echo "Transport Layer: ${TRANSPORT_PASSED}/20 passed (5 Python→Python complete)"
echo ""

# PART 2: PROTOCOL 0 TESTS (12 tests)
echo "========================================"
echo "PART 2: PROTOCOL 0 (TEXT/JSON-RPC)"
echo "========================================"
echo ""

echo -e "${BLUE}Test 1/4: Python → Python (Text)${NC}"
run_test "JSON message" "python3 protocol0/test_text_protocol.py --scenario=json"
run_test "Large JSON" "python3 protocol0/test_text_protocol.py --scenario=large_json"
run_test "Invalid JSON" "python3 protocol0/test_text_protocol.py --scenario=invalid_json"
echo ""

# Python → Swift (3 scenarios) - TODO after Swift implementation
echo -e "${YELLOW}Test 2/4: Python → Swift (requires Swift implementation)${NC}"
echo ""

# Swift → Python (3 scenarios) - TODO after Swift implementation
echo -e "${YELLOW}Test 3/4: Swift → Python (requires Swift implementation)${NC}"
echo ""

# Swift → Swift (3 scenarios) - TODO after Swift implementation
echo -e "${YELLOW}Test 4/4: Swift → Swift (requires Swift implementation)${NC}"
echo ""

PROTO0_PASSED=$((PASSED - TRANSPORT_PASSED))
echo "Protocol 0: ${PROTO0_PASSED}/12 passed (3 Python→Python complete)"
echo ""

# PART 3: PROTOCOL 1 TESTS (16 tests)
echo "========================================"
echo "PART 3: PROTOCOL 1 (BINARY/CHUNKED)"
echo "========================================"
echo ""

echo -e "${BLUE}Test 1/4: Python → Python (Binary)${NC}"
run_test "Binary base (0x00)" "python3 protocol1/test_binary_protocol.py --proto-opts=0x00"
run_test "Compressed (0x01)" "python3 protocol1/test_binary_protocol.py --proto-opts=0x01"
run_test "Encrypted (0x02)" "python3 protocol1/test_binary_protocol.py --proto-opts=0x02"
run_test "Both (0x03)" "python3 protocol1/test_binary_protocol.py --proto-opts=0x03"
echo ""

# Python → Swift (4 scenarios) - TODO after Swift implementation
echo -e "${YELLOW}Test 2/4: Python → Swift (requires Swift implementation)${NC}"
echo ""

# Swift → Python (4 scenarios) - TODO after Swift implementation
echo -e "${YELLOW}Test 3/4: Swift → Python (requires Swift implementation)${NC}"
echo ""

# Swift → Swift (4 scenarios) - TODO after Swift implementation
echo -e "${YELLOW}Test 4/4: Swift → Swift (requires Swift implementation)${NC}"
echo ""

PROTO1_PASSED=$((PASSED - TRANSPORT_PASSED - PROTO0_PASSED))
echo "Protocol 1: ${PROTO1_PASSED}/16 passed (4 Python→Python complete)"
echo ""

# SUMMARY
echo "========================================"
echo "SUMMARY"
echo "========================================"
echo -e "Total Passed:  ${GREEN}${PASSED}${NC}"
echo -e "Total Failed:  ${RED}${FAILED}${NC}"
echo "Total Tests:   $((PASSED + FAILED)) / 48 (target)"
echo "========================================"

if [ "$FAILED" -eq 0 ] && [ "$PASSED" -eq 48 ]; then
    echo -e "${GREEN}✅ ALL INTEROPERABILITY TESTS PASSED${NC}"
    exit 0
elif [ "$FAILED" -eq 0 ] && [ "$PASSED" -eq 12 ]; then
    echo -e "${GREEN}✅ PYTHON IMPLEMENTATION COMPLETE (12/12 tests)${NC}"
    echo -e "${YELLOW}⚠️  Awaiting Swift implementation for full 48-test matrix${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Build Swift implementation (Steps 11-15)"
    echo "  2. Run full interop matrix (48 tests)"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    exit 1
fi
