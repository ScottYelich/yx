# YBS Step: Interop Test Senders

**Step ID:** `ybs-step_k5a0b1c2d3e4`
**Language:** Python
**Prerequisites:** Step j4b complete (SimplePacketBuilder integration test passes)

---

## ⚠️ CRITICAL: Do NOT use canonical/ as proof of completion

The `canonical/` directory contains reference files. **DO NOT** look at `canonical/` to confirm work is done.
Verify ONLY by checking that the sender files exist in `tests/interop/senders/`.

---

## ⚠️ CRITICAL: Import Path

The interop test files are in `tests/interop/senders/`. From there, `../../../src` is the project `src/` directory.

**CORRECT:**
```python
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))
from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packet, TestConfig
```

**WRONG (do NOT use):**
```python
from canonical.python.src.yx.primitives.test_helpers import ...
```

---

## What This Step Builds

Create 5 sender programs in `tests/interop/senders/`:

---

## File 1: `tests/interop/senders/python_sender_proto0.py`

```python
#!/usr/bin/env python3
"""
Protocol 0 test sender. Sends a JSON-RPC message.

Usage: python python_sender_proto0.py <message_json>

Traceability:
- protocol/specs/testing/interoperability-requirements.md (Sender Interface)
"""

import sys
import json
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))

from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packet, TestConfig


def main():
    message = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {"method": "test"}
    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()
    packet = SimplePacketBuilder.build_text_packet(message, guid, key)
    send_udp_packet(packet, "127.0.0.1", port)
    print(f"SENT: {message}")
    sys.exit(0)


if __name__ == "__main__":
    main()
```

---

## File 2: `tests/interop/senders/python_sender_proto1_base.py`

```python
#!/usr/bin/env python3
"""Protocol 1 base sender (no compression, no encryption, protoOpts=0x00)."""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))

from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packets, TestConfig


def main():
    data = bytes.fromhex(sys.argv[1]) if len(sys.argv) > 1 else b"hello"
    packets = SimplePacketBuilder.build_binary_packet(
        data, TestConfig.test_guid(), TestConfig.test_key(),
        proto_opts=0x00, channel_id=0, sequence=0
    )
    send_udp_packets(packets, "127.0.0.1", TestConfig.test_port())
    print(f"SENT: {len(data)} bytes ({len(packets)} packets)")
    sys.exit(0)


if __name__ == "__main__":
    main()
```

---

## File 3: `tests/interop/senders/python_sender_proto1_compressed.py`

```python
#!/usr/bin/env python3
"""Protocol 1 compressed sender (protoOpts=0x01)."""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))

from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packets, TestConfig


def main():
    data = bytes.fromhex(sys.argv[1]) if len(sys.argv) > 1 else b"hello" * 100
    packets = SimplePacketBuilder.build_binary_packet(
        data, TestConfig.test_guid(), TestConfig.test_key(),
        proto_opts=0x01, channel_id=0, sequence=0
    )
    send_udp_packets(packets, "127.0.0.1", TestConfig.test_port())
    print(f"SENT: {len(data)} bytes compressed ({len(packets)} packets)")
    sys.exit(0)


if __name__ == "__main__":
    main()
```

---

## File 4: `tests/interop/senders/python_sender_proto1_encrypted.py`

```python
#!/usr/bin/env python3
"""Protocol 1 encrypted sender (protoOpts=0x02)."""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))

from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packets, TestConfig


def main():
    data = bytes.fromhex(sys.argv[1]) if len(sys.argv) > 1 else b"secret"
    packets = SimplePacketBuilder.build_binary_packet(
        data, TestConfig.test_guid(), TestConfig.test_key(),
        proto_opts=0x02, channel_id=0, sequence=0
    )
    send_udp_packets(packets, "127.0.0.1", TestConfig.test_port())
    print(f"SENT: {len(data)} bytes encrypted ({len(packets)} packets)")
    sys.exit(0)


if __name__ == "__main__":
    main()
```

---

## File 5: `tests/interop/senders/python_sender_proto1_both.py`

```python
#!/usr/bin/env python3
"""Protocol 1 compressed+encrypted sender (protoOpts=0x03)."""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))

from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packets, TestConfig


def main():
    data = bytes.fromhex(sys.argv[1]) if len(sys.argv) > 1 else b"secret" * 100
    packets = SimplePacketBuilder.build_binary_packet(
        data, TestConfig.test_guid(), TestConfig.test_key(),
        proto_opts=0x03, channel_id=0, sequence=0
    )
    send_udp_packets(packets, "127.0.0.1", TestConfig.test_port())
    print(f"SENT: {len(data)} bytes compressed+encrypted ({len(packets)} packets)")
    sys.exit(0)


if __name__ == "__main__":
    main()
```

---

## Verification

```bash
# Make executable
chmod +x tests/interop/senders/*.py

# Verify syntax (dry run - no receiver, just import check)
python -c "import sys, os; sys.path.insert(0, 'src'); from yx.primitives.test_helpers import SimplePacketBuilder, TestConfig; print('OK')"
```

Python import check must succeed.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_k5a0b1c2d3e4-DONE.txt`:

```
STEP: ybs-step_k5a0b1c2d3e4
COMPLETED: [ISO 8601 timestamp]
FILES: tests/interop/senders/python_sender_proto0.py + 4 proto1 variants
VERIFICATION: PASSED
NEXT: ybs-step_k5b0c1d2e3f4
```

Update `BUILD_STATUS.md`: add `- [x] k5a0b1c2d3e4`.
