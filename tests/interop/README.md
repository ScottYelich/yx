# Interoperability Tests

Cross-language YX implementation validation tests.

## Purpose

Verify that Python and Swift (and future language) implementations can exchange YX protocol messages successfully.

## Test Matrix

| Sender | Receiver | Test Script | Status |
|--------|----------|-------------|--------|
| Python | Swift | `test-python-to-swift.sh` | Not yet created |
| Swift | Python | `test-swift-to-python.sh` | Not yet created |
| Python | Python | `test-python-to-python.sh` | Not yet created |
| Swift | Swift | `test-swift-to-swift.sh` | Not yet created |

## Running Tests

### Prerequisites
1. Python implementation built: `../../builds/python-impl/`
2. Swift implementation built: `../../builds/swift-impl/`
3. Both implementations pass their own test suites

### Run All Tests
```bash
./test-all-interop.sh
```

### Run Individual Test
```bash
./test-python-to-swift.sh
```

## Test Scripts (To Be Created)

Scripts will be generated as part of the YBS build process after implementations are complete.

Each script will:
1. Start receiver process
2. Wait for receiver ready
3. Start sender process
4. Verify message exchange
5. Clean up processes
6. Report success/failure

## Expected by Build Process

The YBS build steps will create these test scripts as part of the verification phase, once both implementations exist.
