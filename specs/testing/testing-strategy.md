# YX Testing Strategy Specification

**Version:** 0.1.0
**Last Updated:** 2026-01-18

## Overview

This document defines the testing strategy for YX protocol implementations, based on the reference implementation patterns from the AlgoTrader system.

## Reference Implementation Analysis

The YX protocol was originally implemented and tested in the AlgoTrader system (`../sdts/scott/algotrader`). This specification is informed by that production system's testing approach.

### Reference Implementation Languages

| Language | File Count | Purpose |
|----------|-----------|---------|
| Python | 231 files | Core framework, services, dashboard, algorithms |
| Swift | 17 files | High-performance services, algorithms |
| Bash | 30+ files | Testing scripts, deployment, utilities |

**Key Finding:** Python is the primary implementation language (~93% of code), with Swift for performance-critical components.

### Reference Implementation Testing

**Total Test Files:** ~60+ test files across Python and Swift

**Testing Frameworks Used:**
- **Python:** Pytest with unittest.mock
- **Swift:** XCTest (Apple's native framework)
- **Integration:** Bash scripts for multi-service coordination

---

## Testing Requirements for YX Implementations

### 1. Supported Languages

YX implementations MUST support at least one of:
- **Python** (primary, reference implementation)
- **Swift** (performance-critical scenarios)
- **Other languages** (Rust, Go, JavaScript, etc.) with wire-format compatibility

**Wire Format Compatibility:** All language implementations MUST produce identical packet structures as defined in `../technical/yx-protocol-spec.md`.

### 2. Required Testing Frameworks

#### Python Implementations
- **Unit Testing:** Pytest
- **Async Testing:** pytest-asyncio (`@pytest.mark.asyncio`)
- **Mocking:** unittest.mock (Mock, AsyncMock, MagicMock, patch)
- **Test Organization:** Class-based test structure

#### Swift Implementations
- **Unit Testing:** XCTest
- **Assertions:** XCTAssert family

#### Other Languages
- Use idiomatic testing framework for the language
- Must support async testing if language supports async/await
- Must provide mocking capabilities for network I/O

### 3. Test Categories

All YX implementations MUST include these test categories:

#### Category 1: Unit Tests (Protocol Layer)

**Purpose:** Test individual protocol components in isolation

**Required Test Coverage:**
- Packet building and parsing
- HMAC computation and validation
- GUID generation and padding
- Constant-time HMAC comparison
- Packet serialization/deserialization

**Example from Reference:**
```python
class TestPacketBuilder:
    def test_build_packet(self):
        guid = b'\x01\x02\x03\x04\x05\x06'
        payload = b'test payload'
        key = b'0' * 32

        packet = PacketBuilder.build_packet(guid, payload, key)

        assert len(packet.hmac) == 16
        assert packet.guid == guid
        assert packet.payload == payload
```

#### Category 2: Unit Tests (Protocol Handlers)

**Purpose:** Test Text Protocol and Binary Protocol handlers

**Required Test Coverage:**
- TextProtocol message encoding/decoding
- BinaryProtocol header parsing
- Compression (ZLIB)
- Encryption (AES-256-GCM)
- Chunking and reassembly
- Deduplication logic
- Buffer timeout handling

**Example Pattern:**
```python
class TestBinaryProtocol:
    @pytest.mark.asyncio
    async def test_chunking_large_message(self):
        protocol = BinaryProtocol(key=test_key, chunk_size=1024)
        large_data = b'x' * 5000  # 5KB

        chunks = await protocol.send(large_data, proto_opts=0x00, channel_id=1)

        assert len(chunks) == 5  # 5 chunks for 5KB with 1KB chunks
```

#### Category 3: Unit Tests (Security)

**Purpose:** Test security mechanisms

**Required Test Coverage:**
- HMAC validation (valid and invalid cases)
- HMAC truncation correctness
- AES-GCM encryption/decryption round-trip
- Nonce uniqueness
- Replay protection (duplicate detection)
- Rate limiting (enforce limits, allow under limits)
- Key management (default key, per-peer keys)

**Example Pattern:**
```python
class TestReplayProtection:
    def test_replay_detection(self):
        rp = ReplayProtection(max_age=300.0)
        nonce = b'\x01' * 16

        # First time: should allow
        assert rp.check_and_record(nonce) == True

        # Second time: should reject (replay)
        assert rp.check_and_record(nonce) == False
```

#### Category 4: Network Tests

**Purpose:** Test UDP transport layer

**Required Test Coverage:**
- UDP socket creation and binding
- SO_REUSEADDR, SO_REUSEPORT, SO_BROADCAST flags
- Broadcast packet transmission to 255.255.255.255
- Packet reception from broadcast
- Self-packet filtering (ignore own GUID)
- Multiple listeners on same port (SO_REUSEPORT behavior)

**Example from Reference:**
```python
@pytest.mark.asyncio
async def test_udp_broadcast_reception():
    transport = UDPTransport(guid=test_guid, key_store=key_store, port=50001)
    received = []

    async def on_packet(guid, payload, addr):
        received.append((guid, payload))

    await transport.start(on_packet)
    # Send test packet
    await transport.send(b'test', '255.255.255.255', 50001)
    await asyncio.sleep(0.1)

    assert len(received) == 1
```

#### Category 5: Integration Tests

**Purpose:** Test protocol routing and end-to-end message flow

**Required Test Coverage:**
- Protocol routing (detect Text vs Binary by first byte)
- Complete send path: build → HMAC → send
- Complete receive path: receive → validate HMAC → route → parse
- Text Protocol end-to-end (JSON message)
- Binary Protocol end-to-end (compressed message)
- Binary Protocol end-to-end (encrypted message)
- Binary Protocol end-to-end (compressed + encrypted)
- Multi-chunk message reassembly

**Example Pattern:**
```python
@pytest.mark.asyncio
async def test_text_protocol_end_to_end():
    # Setup sender and receiver
    sender = YXCoordinator(guid=sender_guid, key=key)
    receiver = YXCoordinator(guid=receiver_guid, key=key)

    received_messages = []

    async def on_message(message):
        received_messages.append(message)

    receiver.text_protocol.on_message = on_message

    # Send message
    test_message = {"method": "test", "params": {}}
    await sender.sendText(test_message, "255.255.255.255", 50000)

    await asyncio.sleep(0.1)

    assert len(received_messages) == 1
    assert received_messages[0]["method"] == "test"
```

#### Category 6: Interoperability Tests ⚠️ MANDATORY

**Status:** ✅ **MANDATORY** - CANNOT BE SKIPPED
**Specification:** See `interoperability-requirements.md` for complete details

**Purpose:** Prove actual UDP network communication works between all language implementations

**CRITICAL REQUIREMENT:** Wire format compatibility is NOT sufficient. All implementations MUST demonstrate actual UDP packet exchange over the network.

**Required Test Matrix:**
For N language implementations, N² tests are required:
- Python → Python ✅ MANDATORY
- Python → Swift ✅ MANDATORY
- Swift → Python ✅ MANDATORY
- Swift → Swift ✅ MANDATORY

**Required Test Scenarios (per combination):**
1. Simple payload (ASCII text)
2. Empty payload (zero bytes)
3. Large payload (≥5KB)
4. Multiple packets (≥10 sequential)
5. Invalid key rejection

**Total Tests Required:**
```
For Python + Swift: 2² × 5 = 20 tests
All 20 tests MUST pass - no exceptions
```

**Anti-Patterns (DO NOT DO):**
- ❌ In-memory byte comparison (not real network)
- ❌ Mock sockets (not real UDP)
- ❌ Assuming wire format = network compatibility
- ❌ Skipping any combination

**Required Pattern:**
```python
# CORRECT - Real UDP communication
def test_python_to_swift():
    receiver = start_swift_receiver(port=7777)
    time.sleep(1)
    python_sender.send_udp(payload=b"test", host="127.0.0.1", port=7777)
    received = receiver.wait_for_packet(timeout=5)
    assert received.payload == b"test"
```

**Success Criteria:**
- ✅ All N² × 5 tests pass
- ✅ Real UDP sockets used
- ✅ Actual network communication verified
- ✅ HMAC validation passed
- ✅ Payload matches expected

**Failure Policy:**
If ANY interop test fails:
- ❌ Implementation is NOT complete
- ❌ Cannot promote to canonical/
- ❌ Cannot claim "production ready"

**See Also:** `specs/testing/interoperability-requirements.md` for complete specification

#### Category 7: Performance/Stress Tests (Optional but Recommended)

**Purpose:** Validate performance characteristics

**Recommended Coverage:**
- Throughput: Messages per second
- Latency: Round-trip time
- Memory: Buffer growth under high load
- Packet loss handling
- Large message handling (10MB+)
- Many concurrent channels (1000+)

---

## Test Organization

### Directory Structure

```
<implementation-root>/
├── src/                          # Source code
│   ├── transport/
│   ├── primitives/
│   └── ...
└── tests/                        # All tests
    ├── unit/                     # Unit tests
    │   ├── test_packet_builder.py
    │   ├── test_text_protocol.py
    │   ├── test_binary_protocol.py
    │   ├── test_hmac.py
    │   ├── test_encryption.py
    │   └── test_compression.py
    ├── network/                  # Network layer tests
    │   ├── test_udp_transport.py
    │   ├── test_broadcast.py
    │   └── test_reuseport.py
    ├── integration/              # Integration tests
    │   ├── test_end_to_end.py
    │   ├── test_protocol_routing.py
    │   └── test_chunking.py
    ├── interop/                  # Cross-language tests
    │   ├── test_python_swift.sh
    │   └── receiver.swift
    └── performance/              # Performance tests (optional)
        ├── test_throughput.py
        └── test_latency.py
```

### Test File Naming

- **Python:** `test_*.py` or `*_test.py`
- **Swift:** `*Tests.swift`
- **Shell:** `test_*.sh` or `*_test.sh`

### Test Class/Function Naming

- **Python Classes:** `Test<ComponentName>` (e.g., `TestPacketBuilder`)
- **Python Methods:** `test_<specific_behavior>` (e.g., `test_hmac_validation_rejects_invalid`)
- **Swift Classes:** `<ComponentName>Tests` (e.g., `PacketBuilderTests`)
- **Swift Methods:** `test<SpecificBehavior>` (e.g., `testHMACValidationRejectsInvalid`)

---

## Testing Patterns

### Pattern 1: Arrange-Act-Assert (AAA)

All tests SHOULD follow the AAA pattern:

```python
def test_something(self):
    # Arrange: Set up test data
    packet = create_test_packet()

    # Act: Execute the behavior
    result = validate_packet(packet)

    # Assert: Verify the result
    assert result == expected_value
```

### Pattern 2: Fixtures for Common Setup

Use testing framework fixtures to avoid duplication:

```python
@pytest.fixture
def test_key():
    return b'0' * 32

@pytest.fixture
def test_guid():
    return b'\x01\x02\x03\x04\x05\x06'

def test_build_packet(test_key, test_guid):
    packet = PacketBuilder.build_packet(test_guid, b'payload', test_key)
    assert packet.guid == test_guid
```

### Pattern 3: Mocking for Network I/O

Use mocks to avoid actual network operations in unit tests:

```python
@pytest.mark.asyncio
async def test_send_without_network(mocker):
    mock_socket = mocker.Mock()
    transport = UDPTransport(...)
    transport._socket = mock_socket

    await transport.send(b'test', '255.255.255.255', 50000)

    mock_socket.sendto.assert_called_once()
```

### Pattern 4: Async Test Support

For async code, use appropriate async test decorators:

```python
# Python with pytest
@pytest.mark.asyncio
async def test_async_operation():
    result = await async_function()
    assert result == expected

# Swift with XCTest
func testAsyncOperation() async throws {
    let result = await asyncFunction()
    XCTAssertEqual(result, expected)
}
```

---

## Test Coverage Requirements

### Minimum Coverage Thresholds

- **Line Coverage:** ≥80%
- **Branch Coverage:** ≥70%
- **Critical Paths:** 100% (HMAC validation, encryption, packet parsing)

### Coverage Tools

- **Python:** pytest-cov
- **Swift:** Xcode Code Coverage
- **Other:** Language-appropriate coverage tools

### Running Coverage

```bash
# Python
pytest --cov=src --cov-report=html tests/

# Swift
swift test --enable-code-coverage
```

---

## Verification Criteria

A YX implementation's test suite is **COMPLETE** when:

1. ✅ All 7 test categories have test files
2. ✅ All required test coverage items are tested
3. ✅ Line coverage ≥80%
4. ✅ All tests pass consistently
5. ✅ No flaky tests (pass rate ≥99% over 100 runs)
6. ✅ Tests run in <60 seconds total (excluding performance tests)
7. ✅ Cross-language interop tests pass (if multiple implementations)

---

## Continuous Integration

### CI/CD Requirements

All implementations SHOULD include:
- Automated test execution on every commit
- Coverage reporting
- Test result badges in README
- Failure notifications

### Example GitHub Actions Workflow

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: pip install pytest pytest-cov pytest-asyncio
      - name: Run tests
        run: pytest --cov=src --cov-report=xml tests/
      - name: Upload coverage
        uses: codecov/codecov-action@v2
```

---

## Reference Implementation Testing Stats

From the AlgoTrader YX implementation:

- **Total Test Files:** ~60+
- **Python Test Files:** ~45+
- **Swift Test Files:** 2
- **Shell Test Scripts:** 30+
- **Test Organization:** By component (dashboard, models, core) + integration/debug
- **Frameworks:** Pytest + XCTest + Bash
- **Async Support:** Yes (pytest-asyncio)
- **Mocking:** Yes (unittest.mock)
- **Cross-language Tests:** Yes (Python ↔ Swift interop)

**Key Pattern:** Heavy emphasis on network/debug tests for YX layer validation (HMAC, JSON parsing, UDP broadcast, socket reuse).

---

## Summary

This testing strategy ensures YX implementations are:
- **Correct:** Comprehensive unit tests for all components
- **Secure:** Explicit tests for all security mechanisms
- **Reliable:** Integration tests for end-to-end flows
- **Compatible:** Interop tests for cross-language implementations
- **Performant:** Optional performance tests for production readiness

Implementations following this specification will have production-grade test coverage comparable to the reference AlgoTrader system.
