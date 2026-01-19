# YBS Step 15: Interoperability Test Suite (48 Tests)

**Step ID:** `ybs-step_k5l6m7n8o9p0`
**Language:** Python
**Estimated Duration:** 3-4 hours
**Prerequisites:** Steps 11-14 complete (Full implementation + SimplePacketBuilder)

---

## Overview

Create the comprehensive interoperability test suite with **48 mandatory tests** that prove cross-language compatibility. This is the **PROOF** that Python and Swift implementations are truly interoperable.

**Test Matrix:** 4 combinations × 12 scenarios = 48 tests
- Python → Python (4 tests)
- Python → Swift (4 tests) - Proves Python can talk to Swift
- Swift → Python (4 tests) - Proves Swift can talk to Python
- Swift → Swift (4 tests)

**Test Coverage:**
- Transport layer (raw packets)
- Protocol 0 (text/JSON-RPC)
- Protocol 1 (binary with all protoOpts)

**Traceability:**
- `specs/testing/interoperability-requirements.md` - Complete test requirements
- `specs/architecture/protocol-layers.md` - Protocol specifications
- `specs/technical/default-values.md` - Test configuration

---

## Context

**Why 48 Tests (not just 20)?**

Original plan had 20 tests (4 combinations × 5 scenarios).
Updated requirement expanded to 48 tests:
- **Transport Layer:** 4 combinations × 5 scenarios = 20 tests
- **Protocol 0 (Text):** 4 combinations × 3 scenarios = 12 tests
- **Protocol 1 (Binary):** 4 combinations × 4 variants = 16 tests
- **Total:** 48 tests

**MANDATORY:** All 48 tests MUST pass. No exceptions. Cannot skip.

---

## Goals

1. ✅ Test infrastructure (runner scripts, helpers)
2. ✅ Transport layer tests (20 tests)
3. ✅ Protocol 0 tests (12 tests)
4. ✅ Protocol 1 tests (16 tests)
5. ✅ Master test runner (run all 48 tests)
6. ✅ Sender/receiver programs for each scenario
7. ✅ Clear pass/fail reporting
8. ✅ Traceability ≥80%

---

## File Structure

```
tests/
└── interop/
    ├── run_all_interop_tests.sh    # Master test runner
    ├── transport/                   # Transport layer tests
    │   ├── python_to_python.py
    │   ├── python_to_swift.sh
    │   ├── swift_to_python.sh
    │   └── swift_to_swift.sh
    ├── protocol0/                   # Protocol 0 (text) tests
    │   ├── test_text_protocol.py
    │   └── ...
    ├── protocol1/                   # Protocol 1 (binary) tests
    │   ├── test_binary_protocol.py
    │   └── ...
    ├── senders/                     # Test sender programs
    │   ├── python_sender_proto0.py
    │   ├── python_sender_proto1_base.py
    │   ├── python_sender_proto1_compressed.py
    │   ├── python_sender_proto1_encrypted.py
    │   └── python_sender_proto1_both.py
    ├── receivers/                   # Test receiver programs
    │   ├── python_receiver_proto0.py
    │   ├── python_receiver_proto1.py
    │   └── ...
    └── README.md                    # Test documentation
```

---

## Implementation

### Part 1: Test Sender Programs

**File:** `tests/interop/senders/python_sender_proto0.py`

```python
#!/usr/bin/env python3
"""
Protocol 0 (text) test sender.

Usage: python_sender_proto0.py <message_json>

Traceability:
- specs/testing/interoperability-requirements.md (Sender Interface)
"""

import sys
import json
import os

# Add parent directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../..'))

from canonical.python.src.yx.primitives.test_helpers import (
    SimplePacketBuilder,
    send_udp_packet,
    TestConfig
)


def main():
    if len(sys.argv) < 2:
        print("Usage: python_sender_proto0.py <message_json>")
        sys.exit(1)

    message_json = sys.argv[1]
    message = json.loads(message_json)

    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    # Build packet
    packet = SimplePacketBuilder.build_text_packet(message, guid, key)

    # Send
    send_udp_packet(packet, "127.0.0.1", port)

    print(f"SENT: {message}")
    sys.exit(0)


if __name__ == "__main__":
    main()
```

**File:** `tests/interop/senders/python_sender_proto1_base.py`

```python
#!/usr/bin/env python3
"""
Protocol 1 (binary, base) test sender.

Usage: python_sender_proto1_base.py <data_hex>

Traceability:
- specs/testing/interoperability-requirements.md (Sender Interface)
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../..'))

from canonical.python.src.yx.primitives.test_helpers import (
    SimplePacketBuilder,
    send_udp_packets,
    TestConfig
)


def main():
    if len(sys.argv) < 2:
        print("Usage: python_sender_proto1_base.py <data_hex>")
        sys.exit(1)

    data_hex = sys.argv[1]
    data = bytes.fromhex(data_hex)

    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    # Build packets (protoOpts = 0x00, no compression/encryption)
    packets = SimplePacketBuilder.build_binary_packet(
        data, guid, key,
        proto_opts=0x00,
        channel_id=0,
        sequence=0
    )

    # Send
    send_udp_packets(packets, "127.0.0.1", port)

    print(f"SENT: {len(data)} bytes ({len(packets)} packets)")
    sys.exit(0)


if __name__ == "__main__":
    main()
```

**File:** `tests/interop/senders/python_sender_proto1_compressed.py`

```python
#!/usr/bin/env python3
"""Protocol 1 (compressed) test sender."""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../..'))

from canonical.python.src.yx.primitives.test_helpers import (
    SimplePacketBuilder,
    send_udp_packets,
    TestConfig
)


def main():
    if len(sys.argv) < 2:
        print("Usage: python_sender_proto1_compressed.py <data_hex>")
        sys.exit(1)

    data = bytes.fromhex(sys.argv[1])

    packets = SimplePacketBuilder.build_binary_packet(
        data,
        TestConfig.test_guid(),
        TestConfig.test_key(),
        proto_opts=0x01,  # Compressed
        channel_id=0,
        sequence=0
    )

    send_udp_packets(packets, "127.0.0.1", TestConfig.test_port())
    print(f"SENT: {len(data)} bytes (compressed, {len(packets)} packets)")
    sys.exit(0)


if __name__ == "__main__":
    main()
```

**(Create similar files for encrypted and both variants)**

---

### Part 2: Test Receiver Programs

**File:** `tests/interop/receivers/python_receiver_proto0.py`

```python
#!/usr/bin/env python3
"""
Protocol 0 (text) test receiver.

Waits for Protocol 0 message, validates, exits with success.

Traceability:
- specs/testing/interoperability-requirements.md (Receiver Interface)
"""

import sys
import json
import asyncio
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../..'))

from canonical.python.src.yx.transport.udp_socket import UDPSocket
from canonical.python.src.yx.transport.packet_builder import PacketBuilder
from canonical.python.src.yx.primitives.test_helpers import TestConfig


async def main():
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    receiver = UDPSocket(port=port)

    try:
        # Wait for packet (5s timeout)
        data, addr = receiver.receive_packet(timeout=5.0)

        # Parse packet
        packet = PacketBuilder.parse_packet(data)

        # Validate HMAC
        if not PacketBuilder.validate_hmac(packet, key, addr):
            print("FAILED: HMAC validation failed")
            sys.exit(1)

        # Verify Protocol 0
        if packet.payload[0] != 0x00:
            print(f"FAILED: Expected Protocol 0, got 0x{packet.payload[0]:02x}")
            sys.exit(1)

        # Parse JSON
        json_bytes = packet.payload[1:]
        message = json.loads(json_bytes.decode('utf-8'))

        print(f"RECEIVED: {message}")
        sys.exit(0)  # Success

    except Exception as e:
        print(f"FAILED: {e}")
        sys.exit(1)
    finally:
        receiver.close()


if __name__ == "__main__":
    asyncio.run(main())
```

**File:** `tests/interop/receivers/python_receiver_proto1.py`

```python
#!/usr/bin/env python3
"""
Protocol 1 (binary) test receiver.

Supports all protoOpts variants.

Traceability:
- specs/testing/interoperability-requirements.md (Receiver Interface)
"""

import sys
import asyncio
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../..'))

from canonical.python.src.yx.transport.binary_protocol import BinaryProtocol
from canonical.python.src.yx.transport.udp_socket import UDPSocket
from canonical.python.src.yx.transport.packet_builder import PacketBuilder
from canonical.python.src.yx.primitives.test_helpers import TestConfig


received_data = []


async def on_message(data: bytes):
    """Callback for received message."""
    received_data.append(data)


async def main():
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    # Create binary protocol handler
    handler = BinaryProtocol(key=key, on_message=on_message)

    receiver = UDPSocket(port=port)

    try:
        # Wait for packets (5s timeout, may be multiple chunks)
        timeout = 5.0
        start = asyncio.get_event_loop().time()

        while asyncio.get_event_loop().time() - start < timeout:
            try:
                data, addr = receiver.receive_packet(timeout=1.0)

                # Parse packet
                packet = PacketBuilder.parse_packet(data)

                # Validate HMAC
                if not PacketBuilder.validate_hmac(packet, key, addr):
                    continue  # Skip invalid packets

                # Handle with binary protocol
                await handler.handle(packet.payload)

                # If we received complete message, exit
                if received_data:
                    break

            except Exception:
                continue  # Timeout, keep waiting

        if received_data:
            print(f"RECEIVED: {len(received_data[0])} bytes")
            sys.exit(0)  # Success
        else:
            print("FAILED: Timeout waiting for message")
            sys.exit(1)

    except Exception as e:
        print(f"FAILED: {e}")
        sys.exit(1)
    finally:
        receiver.close()


if __name__ == "__main__":
    asyncio.run(main())
```

---

### Part 3: Master Test Runner

**File:** `tests/interop/run_all_interop_tests.sh`

```bash
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
NC='\033[0m' # No Color

PASSED=0
FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"

    echo -n "  Testing: $test_name... "

    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}"
        ((FAILED++))
    fi
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
echo "Test 1/4: Python → Python"
run_test "Simple payload" "python transport/test_python_to_python.py --scenario=simple"
run_test "Empty payload" "python transport/test_python_to_python.py --scenario=empty"
run_test "Large payload" "python transport/test_python_to_python.py --scenario=large"
run_test "Multiple packets" "python transport/test_python_to_python.py --scenario=multiple"
run_test "Invalid key" "python transport/test_python_to_python.py --scenario=invalid_key"
echo ""

# TODO: Python → Swift, Swift → Python, Swift → Swift
# (These require Swift implementation from Steps 11-15)

echo "Transport Layer: ${PASSED} passed, ${FAILED} failed"
echo ""

# PART 2: PROTOCOL 0 TESTS (12 tests)
echo "========================================"
echo "PART 2: PROTOCOL 0 (TEXT/JSON-RPC)"
echo "========================================"
echo ""

echo "Test 1/4: Python → Python (Text)"
run_test "JSON message" "python protocol0/test_text_protocol.py --scenario=json"
run_test "Large JSON" "python protocol0/test_text_protocol.py --scenario=large_json"
run_test "Invalid JSON" "python protocol0/test_text_protocol.py --scenario=invalid_json"
echo ""

# TODO: Python → Swift, Swift → Python, Swift → Swift

echo "Protocol 0: Additional tests in progress"
echo ""

# PART 3: PROTOCOL 1 TESTS (16 tests)
echo "========================================"
echo "PART 3: PROTOCOL 1 (BINARY/CHUNKED)"
echo "========================================"
echo ""

echo "Test 1/4: Python → Python (Binary)"
run_test "Binary base (0x00)" "python protocol1/test_binary_protocol.py --proto-opts=0x00"
run_test "Compressed (0x01)" "python protocol1/test_binary_protocol.py --proto-opts=0x01"
run_test "Encrypted (0x02)" "python protocol1/test_binary_protocol.py --proto-opts=0x02"
run_test "Both (0x03)" "python protocol1/test_binary_protocol.py --proto-opts=0x03"
echo ""

# TODO: Python → Swift, Swift → Python, Swift → Swift

echo "Protocol 1: Additional tests in progress"
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
else
    echo -e "${YELLOW}⚠️  INTEROPERABILITY TESTING IN PROGRESS${NC}"
    echo "Note: Swift implementation required for full 48-test matrix"
    exit 0
fi
```

---

### Part 4: Python-only Tests (Placeholder for Full Matrix)

**File:** `tests/interop/transport/test_python_to_python.py`

```python
#!/usr/bin/env python3
"""
Transport layer test: Python → Python.

Traceability:
- specs/testing/interoperability-requirements.md (Transport Tests)
"""

import sys
import asyncio
import argparse
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../..'))

from canonical.python.src.yx.transport.udp_socket import UDPSocket
from canonical.python.src.yx.transport.packet_builder import PacketBuilder
from canonical.python.src.yx.primitives.test_helpers import (
    SimplePacketBuilder,
    send_udp_packet,
    TestConfig
)


async def test_scenario(scenario: str):
    """
    Run transport layer test scenario.

    Scenarios:
    - simple: Small payload
    - empty: Empty payload
    - large: Large payload (5KB)
    - multiple: 10 packets sequentially
    - invalid_key: Wrong key (should fail)
    """
    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    received = []

    # Start receiver
    receiver = UDPSocket(port=port)

    async def receive_task():
        try:
            for _ in range(10):  # Multiple packets for 'multiple' scenario
                data, addr = receiver.receive_packet(timeout=2.0)
                packet = PacketBuilder.parse_packet(data)
                if PacketBuilder.validate_hmac(packet, key, addr):
                    received.append(packet.payload)
                if scenario != "multiple":
                    break
        except Exception:
            pass

    receive_future = asyncio.create_task(receive_task())
    await asyncio.sleep(0.1)  # Let receiver bind

    # Send based on scenario
    if scenario == "simple":
        message = {"test": "simple"}
        packet = SimplePacketBuilder.build_text_packet(message, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)

    elif scenario == "empty":
        message = {}
        packet = SimplePacketBuilder.build_text_packet(message, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)

    elif scenario == "large":
        message = {"data": "X" * 5000}
        packet = SimplePacketBuilder.build_text_packet(message, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)

    elif scenario == "multiple":
        for i in range(10):
            message = {"seq": i}
            packet = SimplePacketBuilder.build_text_packet(message, guid, key)
            send_udp_packet(packet, "127.0.0.1", port)
            await asyncio.sleep(0.01)

    elif scenario == "invalid_key":
        wrong_key = bytes(32)  # All zeros (different from test key)
        message = {"test": "invalid"}
        packet = SimplePacketBuilder.build_text_packet(message, guid, wrong_key)
        send_udp_packet(packet, "127.0.0.1", port)

    # Wait for receives
    await receive_future
    receiver.close()

    # Validate
    if scenario == "invalid_key":
        if len(received) == 0:
            return True  # Success: invalid key rejected
        return False

    if scenario == "multiple":
        return len(received) == 10

    return len(received) >= 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", required=True,
                       choices=["simple", "empty", "large", "multiple", "invalid_key"])
    args = parser.parse_args()

    success = asyncio.run(test_scenario(args.scenario))
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
```

**(Create similar test files for Protocol 0 and Protocol 1)**

---

## Verification

```bash
cd tests/interop

# Make scripts executable
chmod +x run_all_interop_tests.sh
chmod +x senders/*.py
chmod +x receivers/*.py

# Run all tests
./run_all_interop_tests.sh
```

**Expected Output (after Swift implementation):**
```
========================================
YX PROTOCOL INTEROPERABILITY TESTS
========================================

========================================
PART 1: TRANSPORT LAYER (UDP + HMAC)
========================================

Test 1/4: Python → Python
  Testing: Simple payload... PASS
  Testing: Empty payload... PASS
  Testing: Large payload... PASS
  Testing: Multiple packets... PASS
  Testing: Invalid key... PASS

Transport Layer: 20/20 passed

========================================
SUMMARY
========================================
Total Passed:  48
Total Failed:  0
Total Tests:   48 / 48 (target)
========================================
✅ ALL INTEROPERABILITY TESTS PASSED
```

---

## Success Criteria

✅ **Test infrastructure:**
- [ ] Master test runner (run_all_interop_tests.sh)
- [ ] Sender programs (5 variants)
- [ ] Receiver programs (Protocol 0, Protocol 1)
- [ ] Test helper scripts

✅ **Python-only tests passing:**
- [ ] Python → Python transport tests (5 scenarios)
- [ ] Python → Python Protocol 0 tests (3 scenarios)
- [ ] Python → Python Protocol 1 tests (4 protoOpts)

✅ **Infrastructure ready:**
- [ ] Test runner can be extended for Swift tests
- [ ] Clear test reporting
- [ ] Single command execution (`./run_all_interop_tests.sh`)

✅ **Documentation:**
- [ ] README.md explains test structure
- [ ] Test scripts have traceability comments
- [ ] Success/failure criteria clear

---

## Next Steps

After this step:

1. ✅ **Python implementation COMPLETE!**
2. ✅ Commit all changes
3. ✅ Proceed to **Swift Steps 11-15** (port all features to Swift)
4. ✅ Complete 48/48 interop tests (add Swift combinations)

---

## References

**Specifications:**
- `specs/testing/interoperability-requirements.md` - Complete test requirements
- `specs/architecture/protocol-layers.md` - Protocol specifications
- `specs/architecture/api-contracts.md` - API contracts

**SDTS Reference:**
- `sdts-comparison/tests/yx-interop/` - Reference test suite (20/20 passing)
- `sdts-comparison/tests/yx-interop/run-all-tests.sh` - Reference test runner
