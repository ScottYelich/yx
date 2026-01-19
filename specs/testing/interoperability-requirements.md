# Interoperability Testing Requirements

**Status:** MANDATORY
**Priority:** CRITICAL
**Skip Policy:** CANNOT BE SKIPPED

---

## Overview

This specification defines the **mandatory interoperability testing requirements** for the YX protocol. Wire format compatibility or in-memory byte comparison is **NOT sufficient**. All language implementations **MUST** demonstrate actual UDP network communication with verified packet exchange.

---

## Core Principle

**Interoperability MUST be proven with running code, not assumptions.**

- ❌ **NOT SUFFICIENT:** "The packets are byte-identical in memory"
- ❌ **NOT SUFFICIENT:** "The wire format matches the spec"
- ❌ **NOT SUFFICIENT:** "Canonical test vectors pass"
- ✅ **REQUIRED:** Actual UDP packets sent over network and received successfully

---

## Mandatory Test Matrix

Every language implementation MUST be tested in all 4 combinations:

| Test ID | Sender | Receiver | Status | Required |
|---------|--------|----------|--------|----------|
| IT-01 | Python | Python | - | ✅ MANDATORY |
| IT-02 | Python | Swift | - | ✅ MANDATORY |
| IT-03 | Swift | Python | - | ✅ MANDATORY |
| IT-04 | Swift | Swift | - | ✅ MANDATORY |

**For N language implementations, N² tests are required.**

Example with 4 languages (Python, Swift, Rust, Go):
- 4 × 4 = **16 mandatory interop tests**

---

## Test Requirements

### 1. Network Communication Required

All tests MUST:
- ✅ Use real UDP sockets (not mocks, not in-memory)
- ✅ Bind to actual network ports
- ✅ Send packets over localhost (127.0.0.1)
- ✅ Use OS network stack (real UDP/IP)
- ❌ NOT use in-memory queues or mocks

### 2. Packet Verification Required

All tests MUST verify:
- ✅ Packet sent successfully
- ✅ Packet received within timeout (e.g., 5 seconds)
- ✅ HMAC validates correctly
- ✅ GUID matches expected value
- ✅ Payload matches expected value
- ✅ Packet length is correct

### 3. Test Scenarios Required

Each test MUST cover:
1. **Simple payload** - ASCII text (e.g., "Hello from {language}!")
2. **Empty payload** - Zero-byte payload
3. **Large payload** - At least 5KB payload
4. **Multiple packets** - Send/receive at least 10 packets sequentially
5. **Invalid key rejection** - Receiver MUST reject packet with wrong key

### 4. Test Execution Required

All tests MUST:
- ✅ Run in under 30 seconds (total)
- ✅ Pass 100% of the time (no flaky tests)
- ✅ Be runnable with single command
- ✅ Report clear pass/fail status
- ✅ Log actual bytes sent/received for debugging

---

## Implementation Requirements

### API Compatibility

To enable interop testing, all implementations MUST provide:

1. **Sender Interface**
   - Function/method to send packet to arbitrary host:port
   - Parameters: GUID, payload, key, destination host, destination port
   - Return: Success/failure indication

2. **Receiver Interface**
   - Function/method to receive packet with timeout
   - Parameters: Key, port to bind, timeout duration
   - Return: Received packet (GUID, payload) or timeout error

3. **Unified Key Format**
   - All implementations MUST accept keys as raw bytes OR
   - Provide conversion utilities between language-specific types

### Executable Requirements

Each implementation MUST provide:

1. **Standalone Sender**
   - Executable: `{language}-sender`
   - Usage: `{language}-sender <payload> <host> <port>`
   - Outputs: "SENT: {payload}" on success
   - Exit code: 0 on success, non-zero on failure

2. **Standalone Receiver**
   - Executable: `{language}-receiver`
   - Usage: `{language}-receiver <port>`
   - Outputs: "RECEIVED: {payload}" on success
   - Exit code: 0 on success, non-zero on failure

3. **Shared Configuration**
   - Use fixed test key: 32 bytes of 0x00 for interop tests
   - Use fixed test GUID: 6 bytes of 0x01 for interop tests
   - Default timeout: 5 seconds

---

## Test Harness Requirements

### Orchestration

The test harness MUST:
- Start receiver process in background
- Wait for receiver to bind (e.g., 1 second)
- Start sender process
- Wait for completion (timeout: 5 seconds)
- Verify both processes succeeded
- Clean up all processes

### Error Reporting

The test harness MUST report:
- Which test combination failed (e.g., "Python → Swift FAILED")
- What went wrong (e.g., "Receiver timeout", "HMAC validation failed")
- Actual bytes sent vs received (for debugging)
- Network errors (e.g., "Port already in use")

### Test Isolation

Each test MUST:
- Use unique port number (avoid conflicts)
- Clean up processes after test
- Not depend on previous test state
- Be runnable in any order

---

## Success Criteria

Interoperability testing is **COMPLETE** when:

✅ All N² test combinations pass (transport layer)
✅ All N² protocol test combinations pass (text + binary)
✅ All test scenarios pass for each combination
✅ Tests run reliably (no flaky failures)
✅ Single command runs all tests
✅ Clear pass/fail reporting

**Completion Definition:**
```
Transport tests = N² × 5 scenarios
Text protocol tests = N² × 3 scenarios
Binary protocol tests = N² × 4 scenarios
Total tests = N² × 12 scenarios
Success = 100% pass rate
```

For Python + Swift (N=2):
```
Transport: 2² × 5 = 20 tests
Text Protocol: 2² × 3 = 12 tests
Binary Protocol: 2² × 4 = 16 tests
Total tests = 48 tests
Success = 48/48 passing
```

---

## Failure Handling

If ANY interop test fails:

1. ❌ Implementation is NOT considered complete
2. ❌ Cannot promote to canonical/
3. ❌ Cannot claim "production ready"
4. ❌ Cannot claim "interoperable"

**No exceptions. No workarounds. Must fix and pass.**

---

## Anti-Patterns (DO NOT DO THIS)

### ❌ Anti-Pattern 1: Mock Network
```python
# WRONG - This does not prove UDP interop
def test_interop():
    packet = sender.build_packet()
    result = receiver.parse_packet(packet)  # In-memory, no network
    assert result == expected
```

### ❌ Anti-Pattern 2: Assume from Wire Format
```python
# WRONG - Byte-identical packets don't prove UDP works
def test_interop():
    python_packet = python_sender.build()
    swift_packet = swift_sender.build()
    assert python_packet == swift_packet  # Only proves format, not network
```

### ❌ Anti-Pattern 3: Skip Combinations
```python
# WRONG - Must test ALL combinations
def test_interop():
    test_python_to_python()  # Only 1 of 4 required tests
    # Skipping Python→Swift, Swift→Python, Swift→Swift
```

### ✅ Correct Pattern: Real Network Communication
```python
# CORRECT - Actual UDP communication
def test_interop():
    receiver = start_receiver(port=7777)
    time.sleep(1)  # Wait for bind
    sender.send_udp(payload="test", host="127.0.0.1", port=7777)
    received = receiver.wait_for_packet(timeout=5)
    assert received.payload == b"test"
```

---

## Standalone Test Suite Requirement ⚠️ MANDATORY

### Comprehensive Test Runner

A **standalone, self-contained test suite** MUST be provided that:

1. ✅ Runs with a single command (no setup, no configuration)
2. ✅ Tests ALL N² language combinations
3. ✅ Tests ALL 5 scenarios per combination
4. ✅ Tests BOTH Protocol 0 (Text) and Protocol 1 (Binary)
5. ✅ Reports clear pass/fail for each test
6. ✅ Reports overall summary
7. ✅ Exits with code 0 on success, non-zero on any failure
8. ✅ Can be run in CI/CD pipelines
9. ✅ Handles timeouts and cleanup automatically
10. ✅ Logs detailed output for debugging failures

**Single Command Requirement:**
```bash
./tests/interop/run_all_interop_tests.sh
```

**No Setup Required:**
- Must not require manual process starting
- Must not require configuration file editing
- Must not require environment variables (except optional overrides)
- Must handle port allocation automatically
- Must clean up processes on exit (success or failure)

**Output Requirement:**
- Must show progress in real-time
- Must report each test result immediately
- Must provide summary at end
- Must be parseable by CI/CD tools

---

## Test Location

All interoperability tests MUST be located in:
```
tests/interop/
├── transport/                      # UDP transport layer tests
│   ├── test_python_to_python.py
│   ├── test_python_to_swift.py
│   ├── test_swift_to_python.py
│   └── test_swift_to_swift.py
├── protocol/                       # Protocol layer tests (NEW)
│   ├── test_text_protocol.py      # Protocol 0 interop
│   └── test_binary_protocol.py    # Protocol 1 interop
├── run_all_interop_tests.sh       # Master test runner
└── README.md                       # Test documentation
```

Single command to run all tests:
```bash
./tests/interop/run_all_interop_tests.sh
```

Expected output:
```
Running YX Protocol Interoperability Tests...

========================================
PART 1: TRANSPORT LAYER TESTS (UDP + HMAC)
========================================

Test 1/4: Python → Python
  ✅ Simple payload: PASS
  ✅ Empty payload: PASS
  ✅ Large payload: PASS
  ✅ Multiple packets: PASS
  ✅ Invalid key rejection: PASS

Test 2/4: Python → Swift
  ✅ Simple payload: PASS
  ✅ Empty payload: PASS
  ✅ Large payload: PASS
  ✅ Multiple packets: PASS
  ✅ Invalid key rejection: PASS

Test 3/4: Swift → Python
  ✅ Simple payload: PASS
  ✅ Empty payload: PASS
  ✅ Large payload: PASS
  ✅ Multiple packets: PASS
  ✅ Invalid key rejection: PASS

Test 4/4: Swift → Swift
  ✅ Simple payload: PASS
  ✅ Empty payload: PASS
  ✅ Large payload: PASS
  ✅ Multiple packets: PASS
  ✅ Invalid key rejection: PASS

Transport Layer: 20/20 tests passed

========================================
PART 2: PROTOCOL LAYER TESTS
========================================

Protocol 0 (Text Protocol) Tests:

Test 1/4: Python → Python (Text)
  ✅ JSON message: PASS
  ✅ Large JSON (>5KB): PASS
  ✅ Invalid JSON rejection: PASS

Test 2/4: Python → Swift (Text)
  ✅ JSON message: PASS
  ✅ Large JSON (>5KB): PASS
  ✅ Invalid JSON rejection: PASS

Test 3/4: Swift → Python (Text)
  ✅ JSON message: PASS
  ✅ Large JSON (>5KB): PASS
  ✅ Invalid JSON rejection: PASS

Test 4/4: Swift → Swift (Text)
  ✅ JSON message: PASS
  ✅ Large JSON (>5KB): PASS
  ✅ Invalid JSON rejection: PASS

Text Protocol: 12/12 tests passed

Protocol 1 (Binary Protocol) Tests:

Test 1/4: Python → Python (Binary)
  ✅ Binary message: PASS
  ✅ Compressed message: PASS
  ✅ Encrypted message: PASS
  ✅ Compressed + encrypted: PASS

Test 2/4: Python → Swift (Binary)
  ✅ Binary message: PASS
  ✅ Compressed message: PASS
  ✅ Encrypted message: PASS
  ✅ Compressed + encrypted: PASS

Test 3/4: Swift → Python (Binary)
  ✅ Binary message: PASS
  ✅ Compressed message: PASS
  ✅ Encrypted message: PASS
  ✅ Compressed + encrypted: PASS

Test 4/4: Swift → Swift (Binary)
  ✅ Binary message: PASS
  ✅ Compressed message: PASS
  ✅ Encrypted message: PASS
  ✅ Compressed + encrypted: PASS

Binary Protocol: 16/16 tests passed

========================================
SUMMARY
========================================
Transport Layer:  20/20 passed ✅
Text Protocol:    12/12 passed ✅
Binary Protocol:  16/16 passed ✅
----------------------------------------
Total:            48/48 passed ✅
========================================
✅ ALL INTEROPERABILITY TESTS PASSED
Exit code: 0
```

---

## Protocol Layer Testing Requirements ⚠️ MANDATORY

In addition to transport layer tests (UDP + HMAC), ALL implementations MUST test protocol-level interoperability.

### Protocol 0: Text Protocol Tests

**Purpose:** Verify JSON message exchange works across implementations

**Required Tests (per language combination):**
1. **Simple JSON message** - Send/receive basic JSON object
2. **Large JSON message** - Send/receive JSON ≥5KB
3. **Invalid JSON rejection** - Receiver MUST reject malformed JSON

**Verification:**
- JSON parses correctly in receiver
- All fields preserved (no data loss)
- Types preserved (strings, numbers, booleans, nulls, arrays, objects)

**Example Test:**
```python
def test_text_protocol_python_to_swift():
    swift_receiver = start_swift_text_receiver(port=7777)
    message = {"method": "test", "params": {"value": 42}}
    python_sender.send_text(message, host="127.0.0.1", port=7777)
    received = swift_receiver.wait_for_message(timeout=5)
    assert received["method"] == "test"
    assert received["params"]["value"] == 42
```

### Protocol 1: Binary Protocol Tests

**Purpose:** Verify binary message exchange with compression/encryption works

**Required Tests (per language combination):**
1. **Binary message** - Send/receive raw binary data
2. **Compressed message** - Send/receive ZLIB-compressed data
3. **Encrypted message** - Send/receive AES-256-GCM encrypted data
4. **Compressed + encrypted** - Send/receive data with both features

**Verification:**
- Binary data preserved exactly (byte-identical)
- Compression/decompression works correctly
- Encryption/decryption works correctly
- Combined compression + encryption works correctly

**Example Test:**
```python
def test_binary_protocol_swift_to_python():
    python_receiver = start_python_binary_receiver(port=7778)
    data = b'\x01\x02\x03\x04' * 1000  # 4KB binary data
    swift_sender.send_binary(data, compressed=True, encrypted=True,
                            host="127.0.0.1", port=7778)
    received = python_receiver.wait_for_message(timeout=5)
    assert received == data  # Must be byte-identical
```

### Test Count Calculation

For N language implementations:

**Transport Layer:**
- N² combinations × 5 scenarios = N² × 5 tests

**Text Protocol (Protocol 0):**
- N² combinations × 3 scenarios = N² × 3 tests

**Binary Protocol (Protocol 1):**
- N² combinations × 4 scenarios = N² × 4 tests

**Total:**
- N² × (5 + 3 + 4) = N² × 12 tests

**For Python + Swift (N=2):**
- Transport: 4 × 5 = 20 tests
- Text Protocol: 4 × 3 = 12 tests
- Binary Protocol: 4 × 4 = 16 tests
- **Total: 48 tests**

**All 48 tests MUST pass for system to be considered complete.**

---

## Build System Integration

### YBS Step Requirements

Each language implementation MUST include an interop testing step:

**Python:**
- Step 11 (after Step 10): Run full interop test suite

**Swift:**
- Step 11 (after Step 10): Run full interop test suite

**Step 11 Title:** "Cross-Language Interoperability Validation"

**Step 11 Success Criteria:**
- All N² × 12 tests pass (transport + text + binary protocols)
- For Python + Swift: 48/48 tests pass
- Clear reporting of which combinations tested
- All 3 test layers pass (transport, text protocol, binary protocol)
- No skipped tests
- Exit code 0 on success

**Step 11 Cannot Be Skipped:**
- Build is NOT complete without passing interop tests
- Cannot promote to canonical/ without passing interop tests
- Step 11 is as mandatory as Step 1

---

## Rationale

**Why is this so strict?**

1. **Wire format compatibility ≠ Network compatibility**
   - Byte-identical packets can still fail over UDP due to:
     - Socket configuration issues
     - Endianness problems
     - Buffer size mismatches
     - Timeout handling bugs

2. **In-memory tests miss real-world issues**
   - Port conflicts
   - Network permissions
   - OS-specific socket behavior
   - Packet loss handling

3. **Cross-language bugs are subtle**
   - Type conversions (bytes vs SymmetricKey)
   - API mismatches (parameter names)
   - Error handling differences

4. **Production deployments require certainty**
   - Cannot assume compatibility
   - Must prove with running code
   - No surprises in production

**This specification ensures YX protocol implementations are truly interoperable, not just theoretically compatible.**

---

## Version History

- **1.0.0** (2026-01-18): Initial specification
