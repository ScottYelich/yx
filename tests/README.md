# System-Level Tests

This directory contains tests that span multiple YX implementations or require system-level validation.

## Purpose

While each implementation (Python, Swift, etc.) has its own unit and integration tests in `builds/<impl>/tests/`, this directory contains tests that:
- Validate cross-implementation compatibility
- Test wire format consistency
- Verify interoperability between languages
- Perform system-level integration testing

## Directory Structure

### interop/
Cross-implementation interoperability tests

**Purpose:** Verify that different language implementations can communicate

**Contents:**
- `test-python-to-swift.sh` - Python sender → Swift receiver
- `test-swift-to-python.sh` - Swift sender → Python receiver
- `test-python-to-python.sh` - Python sender → Python receiver (baseline)
- `test-swift-to-swift.sh` - Swift sender → Swift receiver (baseline)
- `test-all-interop.sh` - Run all interop tests
- Helper scripts and test data

**Test Flow Example:**
```bash
#!/bin/bash
# test-python-to-swift.sh

echo "Starting Swift receiver..."
cd ../../builds/swift-impl
swift run receiver --port 50001 &
RECEIVER_PID=$!

sleep 1

echo "Sending from Python..."
cd ../../builds/python-impl
python3 -m sender --port 50001 --message '{"method":"test","params":{}}'

sleep 1

echo "Verifying reception..."
# Check logs, exit codes, etc.

kill $RECEIVER_PID
```

## Running Tests

### Prerequisites
- Both Python and Swift implementations must be built
- Implementations must be in `builds/python-impl/` and `builds/swift-impl/`
- Canonical test vectors must exist in `canonical/test-vectors/`

### Run All Interop Tests
```bash
cd tests/interop
./test-all-interop.sh
```

### Run Individual Test
```bash
cd tests/interop
./test-python-to-swift.sh
```

## Test Requirements

Interop tests MUST verify:
1. **Message delivery:** Receiver gets exact message sent
2. **HMAC validation:** Packets pass HMAC check
3. **Payload parsing:** JSON/binary payload parsed correctly
4. **Round-trip:** Send → Receive → Process → Respond → Verify
5. **Protocol support:** Both Text (Protocol 0) and Binary (Protocol 1)

## Success Criteria

All interop tests MUST:
- Exit with code 0 (success)
- Log successful message exchange
- Verify HMAC validation passed
- Verify payload matches expected
- Complete within timeout (10 seconds default)

## Failure Handling

If interop test fails:
1. Check implementation logs
2. Verify canonical test vectors pass for each implementation individually
3. Use packet capture (tcpdump) to inspect wire format
4. Compare HMAC computation between implementations
5. File issue with both implementations

## Adding New Interop Tests

When adding new test:

1. Create test script in `tests/interop/`
2. Follow naming convention: `test-<sender>-to-<receiver>.sh`
3. Include in `test-all-interop.sh`
4. Document test purpose in script header
5. Commit test script

## Performance Tests (Future)

Future additions may include:
- `performance/` - Cross-implementation performance comparison
- `stress/` - High-load system tests
- `latency/` - Round-trip latency measurements

## Notes

- These tests run AFTER all implementations are built
- Tests assume implementations are in standard build directories
- Tests may require network access (localhost UDP)
- Tests are part of CI/CD validation (after all builds pass)
