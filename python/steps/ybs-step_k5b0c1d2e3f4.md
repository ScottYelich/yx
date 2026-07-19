# YBS Step: Interop Test Receivers

**Step ID:** `ybs-step_k5b0c1d2e3f4`
**Language:** Python
**Prerequisites:** Step k5a complete (senders exist)

---

## ⚠️ CRITICAL: Do NOT use canonical/ as proof of completion

The `canonical/` directory contains reference files. **DO NOT** look at `canonical/` to confirm work is done.
Verify ONLY by checking that receiver files exist in `tests/interop/receivers/`.

---

## ⚠️ CRITICAL: UDPSocket API

```python
# CORRECT usage:
receiver = UDPSocket(port=port)
receiver.create_socket()
receiver.socket.settimeout(5.0)   # Set timeout on underlying socket
receiver.bind()
guid, payload, addr = receiver.receive_packet(key)
# Returns (guid: bytes, payload: bytes, addr: (host, port))
# Raises socket.timeout if no packet arrives within timeout
# Raises ValueError if HMAC validation fails
```

**DO NOT use:** `receiver.receive_packet(timeout=5.0)` — timeout is NOT a parameter.

---

## ⚠️ CRITICAL: Import Path

From `tests/interop/receivers/`, the path to `src/` is `../../../src`:
```python
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))
from yx.transport.udp_socket import UDPSocket
```

---

## What This Step Builds

Create 2 receiver programs in `tests/interop/receivers/`:

---

## File 1: `tests/interop/receivers/python_receiver_proto0.py`

```python
#!/usr/bin/env python3
"""
Protocol 0 test receiver. Waits for Protocol 0 packet and exits.

Exit code: 0 = success, 1 = failure

Traceability:
- protocol/specs/testing/interoperability-requirements.md (Receiver Interface)
"""

import sys
import json
import socket
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))

from yx.transport.udp_socket import UDPSocket
from yx.primitives.test_helpers import TestConfig


def main():
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    receiver = UDPSocket(port=port)
    receiver.create_socket()
    receiver.socket.settimeout(5.0)
    receiver.bind()

    try:
        guid, payload, addr = receiver.receive_packet(key)

        if payload[0] != 0x00:
            print(f"FAILED: Expected Protocol 0, got 0x{payload[0]:02x}")
            sys.exit(1)

        message = json.loads(payload[1:].decode('utf-8'))
        print(f"RECEIVED: {message}")
        sys.exit(0)

    except socket.timeout:
        print("FAILED: Timeout waiting for packet")
        sys.exit(1)
    except Exception as e:
        print(f"FAILED: {e}")
        sys.exit(1)
    finally:
        receiver.close()


if __name__ == "__main__":
    main()
```

---

## File 2: `tests/interop/receivers/python_receiver_proto1.py`

```python
#!/usr/bin/env python3
"""
Protocol 1 test receiver. Handles all protoOpts variants.

Waits for complete binary message (may be multiple chunks).
Exit code: 0 = success, 1 = failure

Traceability:
- protocol/specs/testing/interoperability-requirements.md (Receiver Interface)
"""

import sys
import asyncio
import socket
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))

from yx.transport.udp_socket import UDPSocket
from yx.transport.binary_protocol import BinaryProtocol
from yx.primitives.test_helpers import TestConfig

received_data = []


async def on_message(data: bytes):
    received_data.append(data)


async def main():
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    handler = BinaryProtocol(key=key, on_message=on_message)
    receiver = UDPSocket(port=port)
    receiver.create_socket()
    receiver.socket.settimeout(1.0)
    receiver.bind()

    timeout = 5.0
    start = asyncio.get_event_loop().time()

    try:
        while asyncio.get_event_loop().time() - start < timeout:
            try:
                guid, payload, addr = receiver.receive_packet(key)
                await handler.handle(payload)
                if received_data:
                    break
            except socket.timeout:
                pass
            except Exception:
                pass
            await asyncio.sleep(0.01)

        if received_data:
            print(f"RECEIVED: {len(received_data[0])} bytes")
            sys.exit(0)
        else:
            print("FAILED: Timeout — no complete message received")
            sys.exit(1)

    finally:
        receiver.close()


if __name__ == "__main__":
    asyncio.run(main())
```

---

## Verification

```bash
# Import check
python -c "
import sys
sys.path.insert(0, 'src')
from yx.transport.udp_socket import UDPSocket
from yx.transport.binary_protocol import BinaryProtocol
print('OK')
"
```

Import check must succeed.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_k5b0c1d2e3f4-DONE.txt`:

```
STEP: ybs-step_k5b0c1d2e3f4
COMPLETED: [ISO 8601 timestamp]
FILES: tests/interop/receivers/python_receiver_proto0.py, python_receiver_proto1.py
VERIFICATION: PASSED
NEXT: ybs-step_k5c0d1e2f3a4
```

Update `BUILD_STATUS.md`: add `- [x] k5b0c1d2e3f4`.
