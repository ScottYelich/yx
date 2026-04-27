# YX Protocol Interoperability Test Suite

**Status:** 12/48 tests complete (Python→Python only)

## Overview

This is the **MANDATORY** interoperability test suite that proves cross-language compatibility for the YX protocol. All 48 tests MUST pass before the system is considered complete.

**Traceability:**
- `specs/testing/interoperability-requirements.md` - Complete requirements
- `specs/architecture/protocol-layers.md` - Protocol specifications

## Test Matrix

The test suite runs **N² × 12 = 48 tests** for N=2 languages (Python, Swift):

### Transport Layer (20 tests)
- 4 language combinations × 5 scenarios = 20 tests
- **Scenarios:**
  1. Simple payload - Basic UDP packet with small payload
  2. Empty payload - Packet with empty payload
  3. Large payload - Packet with 5KB+ payload
  4. Multiple packets - 10 sequential packets
  5. Invalid key - Wrong HMAC key (should fail validation)

### Protocol 0 (Text/JSON-RPC) (12 tests)
- 4 language combinations × 3 scenarios = 12 tests
- **Scenarios:**
  1. JSON message - Valid JSON-RPC request
  2. Large JSON - JSON message >5KB
  3. Invalid JSON - Malformed JSON (should fail parsing)

### Protocol 1 (Binary/Chunked) (16 tests)
- 4 language combinations × 4 protoOpts = 16 tests
- **Scenarios:**
  1. Base (0x00) - No compression/encryption
  2. Compressed (0x01) - zlib compression
  3. Encrypted (0x02) - XOR encryption
  4. Both (0x03) - Compressed + encrypted

## Current Status

### Completed (12 tests)
- ✅ Python → Python (Transport): 5/5 tests
- ✅ Python → Python (Protocol 0): 3/3 tests
- ✅ Python → Python (Protocol 1): 4/4 tests

### Pending (36 tests)
- ⏳ Python → Swift: 12 tests (requires Swift implementation)
- ⏳ Swift → Python: 12 tests (requires Swift implementation)
- ⏳ Swift → Swift: 12 tests (requires Swift implementation)

## Running Tests

### Run All Tests
```bash
cd tests/interop
./run_all_interop_tests.sh
```

### Run Individual Test Suites
```bash
# Transport layer tests
python3 transport/test_python_to_python.py --scenario=simple
python3 transport/test_python_to_python.py --scenario=empty
python3 transport/test_python_to_python.py --scenario=large
python3 transport/test_python_to_python.py --scenario=multiple
python3 transport/test_python_to_python.py --scenario=invalid_key

# Protocol 0 tests
python3 protocol0/test_text_protocol.py --scenario=json
python3 protocol0/test_text_protocol.py --scenario=large_json
python3 protocol0/test_text_protocol.py --scenario=invalid_json

# Protocol 1 tests
python3 protocol1/test_binary_protocol.py --proto-opts=0x00
python3 protocol1/test_binary_protocol.py --proto-opts=0x01
python3 protocol1/test_binary_protocol.py --proto-opts=0x02
python3 protocol1/test_binary_protocol.py --proto-opts=0x03
```

## Directory Structure

```
tests/interop/
├── run_all_interop_tests.sh   # Master test runner
├── README.md                   # This file
├── transport/                  # Transport layer tests
│   └── test_python_to_python.py
├── protocol0/                  # Protocol 0 (text) tests
│   └── test_text_protocol.py
├── protocol1/                  # Protocol 1 (binary) tests
│   └── test_binary_protocol.py
├── senders/                    # Standalone sender programs
│   ├── python_sender_proto0.py
│   ├── python_sender_proto1_base.py
│   ├── python_sender_proto1_compressed.py
│   ├── python_sender_proto1_encrypted.py
│   └── python_sender_proto1_both.py
└── receivers/                  # Standalone receiver programs
    ├── python_receiver_proto0.py
    └── python_receiver_proto1.py
```

## Test Design

Each test follows this pattern:

1. **Sender** - Builds packet with specific protocol/options → sends via UDP → exits
2. **Receiver** - Listens on UDP → validates packet → parses protocol → exits
3. **Validator** - Verifies received data matches sent data

All tests use **real UDP sockets** (not mocks) to prove actual network communication works.

## Adding Swift Tests

After Swift implementation is complete:

1. Create Swift sender/receiver programs in `senders/` and `receivers/`
2. Add test combinations to `run_all_interop_tests.sh`:
   - Python → Swift (12 tests)
   - Swift → Python (12 tests)
   - Swift → Swift (12 tests)
3. Verify all 48 tests pass

## Success Criteria

The system is **NOT COMPLETE** until:
- ✅ All 48 tests pass
- ✅ Python → Python: 12 tests (complete)
- ✅ Python → Swift: 12 tests (pending)
- ✅ Swift → Python: 12 tests (pending)
- ✅ Swift → Swift: 12 tests (pending)

**No exceptions. No skipping. Wire format compatibility ≠ interoperability.**
