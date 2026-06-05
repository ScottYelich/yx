#!/bin/bash
#
# Master runner for the YX interoperability suite (all 48 tests).
#
# Builds the Swift interop programs, then runs the full cross-language matrix
# over real UDP sockets:
#   - Transport layer : 4 combos x 5 scenarios = 20 tests
#   - Protocol 0 (text): 4 combos x 3 scenarios = 12 tests
#   - Protocol 1 (bin) : 4 combos x 4 scenarios = 16 tests
#   = 48 tests  (Python<->Python, Python<->Swift, Swift<->Python, Swift<->Swift)
#
# Traceability:
# - specs/testing/interoperability-requirements.md
# - tests/interop/run_matrix.py (the matrix driver)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building Swift interop programs..."
( cd swift-interop && swift build >/dev/null )

echo "Running full 48-test interop matrix..."
exec python3 run_matrix.py
