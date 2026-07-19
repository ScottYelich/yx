# YBS Step: SimplePacketBuilder Integration Test

**Step ID:** `ybs-step_j4b0c1d2e3f4`
**Language:** Python
**Prerequisites:** Step j4a complete (test_helpers.py exists and tests pass)

---

## ⚠️ CRITICAL: Do NOT use canonical/ as proof of completion

The `canonical/` directory contains reference files. **DO NOT** look at `canonical/` to confirm work is done.
Verify ONLY by:
1. File exists at `{{CONFIG:impl_src}}/primitives/test_simple_packet_builder_integration.py`
2. Integration test passes

Your target directory is `{{CONFIG:impl_src}}` (resolves to `src/yx`).

---

## ⚠️ CRITICAL: UDPSocket API

`UDPSocket.receive_packet(key, buffer_size=65507)` returns `(guid, payload, addr)`.
There is NO `timeout` parameter on `receive_packet`.
To set a timeout, use: `receiver.socket.settimeout(seconds)` BEFORE calling `receive_packet`.
You MUST call `receiver.create_socket()` then `receiver.bind()` before receiving.

```python
receiver = UDPSocket(port=port)
receiver.create_socket()
receiver.socket.settimeout(2.0)
receiver.bind()
guid, payload, addr = receiver.receive_packet(key)  # Correct
```

---

## What This Step Builds

Create `{{CONFIG:impl_src}}/primitives/test_simple_packet_builder_integration.py` — integration test that builds, sends, and receives a packet.

---

## Implementation

**File:** `{{CONFIG:impl_src}}/primitives/test_simple_packet_builder_integration.py`

```python
"""
Integration test: Build → Send → Receive using SimplePacketBuilder.

Tests that SimplePacketBuilder packets can be received by full YX framework.

Traceability:
- protocol/specs/testing/interoperability-requirements.md (Test Pattern)
"""

import pytest
import asyncio
import socket
import os
from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packet, TestConfig
from yx.transport.udp_socket import UDPSocket


@pytest.mark.asyncio
async def test_build_send_receive_proto0():
    """
    Integration: build text packet with SimplePacketBuilder,
    send via UDP, receive with UDPSocket.
    """
    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    received_payloads = []

    # Build packet
    message = {"method": "test", "params": {"value": 42}}
    packet_bytes = SimplePacketBuilder.build_text_packet(message, guid, key)

    # Start receiver in a thread (receive_packet is synchronous)
    receiver = UDPSocket(port=port)
    receiver.create_socket()
    receiver.socket.settimeout(3.0)
    receiver.bind()

    async def receive_task():
        try:
            await asyncio.sleep(0.1)  # brief yield for sender
            guid_r, payload_r, addr = receiver.receive_packet(key)
            received_payloads.append(payload_r)
        except (socket.timeout, Exception):
            pass
        finally:
            receiver.close()

    # Run receiver and sender concurrently
    recv_task = asyncio.create_task(receive_task())
    await asyncio.sleep(0.05)

    # Send
    send_udp_packet(packet_bytes, "127.0.0.1", port)

    # Wait for receiver
    await recv_task

    assert len(received_payloads) == 1
    assert received_payloads[0][0] == 0x00  # Protocol 0 marker
```

---

## Verification

```bash
pytest {{CONFIG:impl_src}}/primitives/test_simple_packet_builder_integration.py -v
```

The integration test must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_j4b0c1d2e3f4-DONE.txt`:

```
STEP: ybs-step_j4b0c1d2e3f4
COMPLETED: [ISO 8601 timestamp]
FILES: src/yx/primitives/test_simple_packet_builder_integration.py
VERIFICATION: PASSED
NEXT: ybs-step_k5a0b1c2d3e4
```

Update `BUILD_STATUS.md`: add `- [x] j4b0c1d2e3f4`.
