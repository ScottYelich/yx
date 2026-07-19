# YBS Step: Python-to-Python Interop Tests

**Step ID:** `ybs-step_k5c0d1e2f3a4`
**Language:** Python
**Prerequisites:** Steps k5a, k5b complete (senders and receivers exist)

---

## ⚠️ CRITICAL: Do NOT use canonical/ as proof of completion

The `canonical/` directory contains reference files. **DO NOT** look at `canonical/` to confirm work is done.
Verify ONLY by:
1. Test files exist in `tests/interop/transport/`, `tests/interop/protocol0/`, `tests/interop/protocol1/`
2. Tests pass when run

---

## ⚠️ CRITICAL: Import Paths and UDPSocket API

From `tests/interop/transport/` (and similar subdirs), path to `src/` is `../../../src`:
```python
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))
```

UDPSocket API:
```python
receiver = UDPSocket(port=port)
receiver.create_socket()
receiver.socket.settimeout(2.0)
receiver.bind()
guid, payload, addr = receiver.receive_packet(key)  # returns (guid, payload, addr)
```

PacketBuilder.validate_hmac takes 2 args: `validate_hmac(packet, key)` — NO addr argument.

---

## What This Step Builds

Three test files for Python-to-Python testing:

---

## File 1: `tests/interop/transport/test_python_to_python.py`

```python
#!/usr/bin/env python3
"""
Transport layer test: Python → Python.

Tests 5 scenarios:
- simple: basic payload
- empty: empty JSON
- large: large payload
- multiple: 10 sequential packets
- invalid_key: wrong key (must be rejected)

Traceability:
- protocol/specs/testing/interoperability-requirements.md (Transport Tests)
"""

import sys
import asyncio
import argparse
import socket
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))

from yx.transport.udp_socket import UDPSocket
from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packet, TestConfig


async def run_scenario(scenario: str) -> bool:
    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()
    received = []

    receiver = UDPSocket(port=port)
    receiver.create_socket()
    receiver.socket.settimeout(2.0)
    receiver.bind()

    async def recv_loop(n: int):
        for _ in range(n):
            try:
                guid_r, payload_r, addr = receiver.receive_packet(key)
                received.append(payload_r)
            except socket.timeout:
                break
            except Exception:
                break

    await asyncio.sleep(0.05)

    if scenario == "simple":
        packet = SimplePacketBuilder.build_text_packet({"test": "simple"}, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)
        await recv_loop(1)
        result = len(received) == 1

    elif scenario == "empty":
        packet = SimplePacketBuilder.build_text_packet({}, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)
        await recv_loop(1)
        result = len(received) == 1

    elif scenario == "large":
        packet = SimplePacketBuilder.build_text_packet({"data": "X" * 5000}, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)
        await recv_loop(1)
        result = len(received) == 1

    elif scenario == "multiple":
        for i in range(10):
            packet = SimplePacketBuilder.build_text_packet({"seq": i}, guid, key)
            send_udp_packet(packet, "127.0.0.1", port)
        await recv_loop(10)
        result = len(received) == 10

    elif scenario == "invalid_key":
        wrong_key = bytes([0xFF] * 32)
        packet = SimplePacketBuilder.build_text_packet({"test": "bad"}, guid, wrong_key)
        send_udp_packet(packet, "127.0.0.1", port)
        await recv_loop(1)
        result = len(received) == 0  # Must be rejected

    else:
        result = False

    receiver.close()
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", required=True,
                        choices=["simple", "empty", "large", "multiple", "invalid_key"])
    args = parser.parse_args()
    success = asyncio.run(run_scenario(args.scenario))
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
```

---

## File 2: `tests/interop/protocol0/test_text_protocol.py`

```python
#!/usr/bin/env python3
"""
Protocol 0 test: Python → Python text/JSON-RPC.

Scenarios: json, large_json, unicode

Traceability:
- protocol/specs/testing/interoperability-requirements.md (Protocol 0 Tests)
"""

import sys
import asyncio
import argparse
import socket
import json
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))

from yx.transport.udp_socket import UDPSocket
from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packet, TestConfig


async def run_scenario(scenario: str) -> bool:
    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()
    received = []

    receiver = UDPSocket(port=port)
    receiver.create_socket()
    receiver.socket.settimeout(2.0)
    receiver.bind()

    await asyncio.sleep(0.05)

    if scenario == "json":
        msg = {"method": "test.hello", "params": {"name": "TestSender"}, "id": 1}
        packet = SimplePacketBuilder.build_text_packet(msg, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)
        try:
            guid_r, payload_r, addr = receiver.receive_packet(key)
            assert payload_r[0] == 0x00
            parsed = json.loads(payload_r[1:].decode('utf-8'))
            assert parsed == msg
            received.append(payload_r)
        except Exception:
            pass

    elif scenario == "large_json":
        msg = {"data": "A" * 10000, "id": 2}
        packet = SimplePacketBuilder.build_text_packet(msg, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)
        try:
            guid_r, payload_r, addr = receiver.receive_packet(key)
            received.append(payload_r)
        except Exception:
            pass

    elif scenario == "unicode":
        msg = {"message": "Hello 世界 🌍", "id": 3}
        packet = SimplePacketBuilder.build_text_packet(msg, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)
        try:
            guid_r, payload_r, addr = receiver.receive_packet(key)
            parsed = json.loads(payload_r[1:].decode('utf-8'))
            assert parsed == msg
            received.append(payload_r)
        except Exception:
            pass

    receiver.close()
    return len(received) == 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", required=True, choices=["json", "large_json", "unicode"])
    args = parser.parse_args()
    success = asyncio.run(run_scenario(args.scenario))
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
```

---

## File 3: `tests/interop/protocol1/test_binary_protocol.py`

```python
#!/usr/bin/env python3
"""
Protocol 1 test: Python → Python binary/chunked.

Tests all 4 protoOpts variants.

Traceability:
- protocol/specs/testing/interoperability-requirements.md (Protocol 1 Tests)
"""

import sys
import asyncio
import argparse
import socket
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))

from yx.transport.udp_socket import UDPSocket
from yx.transport.binary_protocol import BinaryProtocol
from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packets, TestConfig


async def run_scenario(proto_opts_hex: str) -> bool:
    proto_opts = int(proto_opts_hex, 16)
    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()
    received = []

    async def on_message(data: bytes):
        received.append(data)

    original = b"Test data for Protocol 1 " * 20
    handler = BinaryProtocol(key=key, on_message=on_message)

    receiver = UDPSocket(port=port)
    receiver.create_socket()
    receiver.socket.settimeout(1.0)
    receiver.bind()

    # Build and send
    packets = SimplePacketBuilder.build_binary_packet(
        original, guid, key, proto_opts=proto_opts
    )
    send_udp_packets(packets, "127.0.0.1", port)

    # Receive loop
    timeout = 3.0
    start = asyncio.get_event_loop().time()
    while asyncio.get_event_loop().time() - start < timeout:
        try:
            guid_r, payload_r, addr = receiver.receive_packet(key)
            await handler.handle(payload_r)
            if received:
                break
        except socket.timeout:
            pass
        except Exception:
            pass
        await asyncio.sleep(0.01)

    receiver.close()

    if received:
        assert received[0] == original
        return True
    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--proto-opts", required=True, choices=["0x00", "0x01", "0x02", "0x03"])
    args = parser.parse_args()
    success = asyncio.run(run_scenario(args.proto_opts))
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
```

---

## Verification

```bash
# Run transport tests
python tests/interop/transport/test_python_to_python.py --scenario=simple
python tests/interop/transport/test_python_to_python.py --scenario=empty
python tests/interop/transport/test_python_to_python.py --scenario=large
python tests/interop/transport/test_python_to_python.py --scenario=multiple
python tests/interop/transport/test_python_to_python.py --scenario=invalid_key

# Run protocol0 tests
python tests/interop/protocol0/test_text_protocol.py --scenario=json
python tests/interop/protocol0/test_text_protocol.py --scenario=large_json
python tests/interop/protocol0/test_text_protocol.py --scenario=unicode

# Run protocol1 tests
python tests/interop/protocol1/test_binary_protocol.py --proto-opts=0x00
python tests/interop/protocol1/test_binary_protocol.py --proto-opts=0x01
python tests/interop/protocol1/test_binary_protocol.py --proto-opts=0x02
python tests/interop/protocol1/test_binary_protocol.py --proto-opts=0x03
```

All 12 tests must exit with code 0.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_k5c0d1e2f3a4-DONE.txt`:

```
STEP: ybs-step_k5c0d1e2f3a4
COMPLETED: [ISO 8601 timestamp]
FILES: tests/interop/transport/test_python_to_python.py, protocol0/test_text_protocol.py, protocol1/test_binary_protocol.py
VERIFICATION: PASSED (12/12 tests exit 0)
NEXT: ybs-step_k5d0e1f2a3b4
```

Update `BUILD_STATUS.md`: add `- [x] k5c0d1e2f3a4`.
