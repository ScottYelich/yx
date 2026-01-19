# Step 8: UDP Send and Receive

**Version**: 0.1.0

## Overview

Implement UDP send/receive with packet building and parsing integration.

## Step Objectives

1. Send YX packets via UDP broadcast
2. Receive and parse YX packets
3. Test send/receive with loopback
4. 100% coverage

## Prerequisites

- Step 7 completed

## Traceability

**Implements**: specs/technical/yx-protocol-spec.md § UDP Transport

## Instructions

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
