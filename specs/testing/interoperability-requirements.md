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

✅ All N² test combinations pass
✅ All 5 test scenarios pass for each combination
✅ Tests run reliably (no flaky failures)
✅ Single command runs all tests
✅ Clear pass/fail reporting

**Completion Definition:**
```
Total tests = N² × 5 scenarios
Success = 100% pass rate
```

For Python + Swift:
```
Total tests = 2² × 5 = 20 tests
Success = 20/20 passing
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

## Test Location

All interoperability tests MUST be located in:
```
tests/interop/
├── test_python_to_python.py
├── test_python_to_swift.py
├── test_swift_to_python.py
├── test_swift_to_swift.py
└── run_all_interop_tests.sh
```

Single command to run all tests:
```bash
./tests/interop/run_all_interop_tests.sh
```

Expected output:
```
Running YX Protocol Interoperability Tests...

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

========================================
Total: 20 tests
Passed: 20
Failed: 0
========================================
✅ ALL INTEROPERABILITY TESTS PASSED
```

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
- All N² × 5 tests pass
- Clear reporting of which combinations tested
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
