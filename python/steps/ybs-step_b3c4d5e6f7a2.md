# Step 8: UDP Send and Receive

**Version**: 0.1.0

## Overview

Implement UDP send/receive with packet building and parsing integration.

## What This Step Builds

Adds asyncio-based `send_packet()` and `receive_packet()` operations to `UDPSocket`, enabling non-blocking packet I/O with proper error handling and timeout support.

## Step Objectives

1. Send YX packets via UDP broadcast
2. Receive and parse YX packets
3. Test send/receive with loopback
4. 100% coverage

## Prerequisites

- Step 7 completed

## Traceability

**Implements**: protocol/specs/technical/yx-protocol-spec.md § UDP Transport

## Instructions

### Before Starting — Record Start Time

Record the current timestamp in ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`
This is used for duration calculation in the DONE file.

### 1. Add Send/Receive to UDPSocket

Update `src/yx/transport/udp_socket.py`:

```python
# Add to existing class

from .packet_builder import PacketBuilder

class UDPSocket:
    # ... existing code ...

    def send_packet(self, guid: bytes, payload: bytes, key: bytes, host: str = '255.255.255.255', port: int = 50000):
        """Send YX packet via UDP."""
        if self.socket is None:
            self.create_socket()

        data = PacketBuilder.build_and_serialize(guid, payload, key)
        self.socket.sendto(data, (host, port))

    def receive_packet(self, key: bytes, buffer_size: int = 65507) -> Tuple[bytes, bytes, Tuple[str, int]]:
        """
        Receive and parse YX packet.

        Returns:
            (guid, payload, addr) tuple or raises exception
        """
        if self.socket is None:
            raise RuntimeError("Socket not created")

        data, addr = self.socket.recvfrom(buffer_size)
        packet = PacketBuilder.parse_and_validate(data, key)

        if packet is None:
            raise ValueError("Invalid packet received")

        return packet.guid, packet.payload, addr
```

### 2. Create Tests

Create `tests/unit/test_udp_send_receive.py`:

```python
"""Test UDP send/receive."""

import socket
import pytest
from yx.transport import UDPSocket


class TestUDPSendReceive:
    """Test send/receive functionality."""

    def test_send_packet(self):
        """Test sending packet."""
        key = b'\\x00' * 32
        sender = UDPSocket(port=0)  # Random port
        sender.bind()

        # Should not raise
        sender.send_packet(b'\\x01'*6, b'test', key, '127.0.0.1', 50010)

        sender.close()

    def test_send_receive_loopback(self):
        """Test sending and receiving on same machine."""
        key = b'\\x00' * 32

        receiver = UDPSocket(port=50011)
        receiver.bind()
        receiver.socket.settimeout(1.0)

        sender = UDPSocket(port=0)
        sender.bind()

        # Send
        sender.send_packet(b'\\x01'*6, b'test payload', key, '127.0.0.1', 50011)

        # Receive
        guid, payload, addr = receiver.receive_packet(key)

        assert guid == b'\\x01' * 6
        assert payload == b'test payload'

        sender.close()
        receiver.close()
```

### 3. Run Tests

```bash
pytest tests/unit/test_udp_send_receive.py -v
```

## Verification

- [ ] Can send packets
- [ ] Can receive packets
- [ ] Loopback test passes

```bash
pytest tests/unit/test_udp_send_receive.py -v
```

## Documentation

**Record end time** and calculate duration (end − start timestamp).

Create `docs/build-history/ybs-step_b3c4d5e6f7a2-DONE.txt`:

```
STEP ybs-step_b3c4d5e6f7a2: UDP Send and Receive
STARTED:    [start timestamp from Before Starting]
COMPLETED:  [ISO 8601 timestamp]
DURATION:   [minutes]

OBJECTIVES COMPLETED:
[copy from Step Objectives above]

FILES CREATED/MODIFIED:
- src/yx/transport/udp_socket.py (extended)
- tests/unit/test_udp_send_receive.py

VERIFICATION: PASSED (attempt [N])

NEXT STEP: ybs-step_c4d5e6f7a2b3 (Integration Tests)
```

Update `BUILD_STATUS.md`: mark this step `[x]` and update **Last Updated** timestamp.

## Success Criteria

This step is successful when:
1. All verification checks pass (within 3 attempts)
2. All required files exist and are valid
3. Build compiles/runs without errors
4. DONE file created in `docs/build-history/`
5. `BUILD_STATUS.md` updated

## Next Steps

After completing this step, proceed to:
- **Next**: `ybs-step_c4d5e6f7a2b3` — Integration Tests

## Version History

### 0.1.0 (2026-04-11)
- Initial step creation
