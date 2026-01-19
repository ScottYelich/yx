# Step 9: Integration Tests

**Version**: 0.1.0

## Overview

Create end-to-end integration tests that verify complete YX packet workflow.

## Step Objectives

1. Test complete build → send → receive → validate flow
2. Test multiple packet exchanges
3. Test with different keys, GUIDs, payloads
4. Integration test coverage

## Prerequisites

- Step 8 completed

## Traceability

**Implements**: specs/testing/testing-strategy.md § Category 5: Integration Tests

## Instructions

### 1. Create Integration Tests

Create `tests/integration/test_packet_flow.py`:

```python
"""Integration tests for complete packet flow."""

import pytest
from yx.transport import UDPSocket, PacketBuilder


class TestPacketFlowIntegration:
    """Test end-to-end packet flows."""

    def test_complete_packet_flow(self):
        """Test build → send → receive → validate."""
        key = b'\\x00' * 32
        guid = b'\\xaa' * 6
        payload = b'integration test payload'

        receiver = UDPSocket(port=50020)
        receiver.bind()
        receiver.socket.settimeout(2.0)

        sender = UDPSocket(port=0)
        sender.bind()

        # Send
        sender.send_packet(guid, payload, key, '127.0.0.1', 50020)

        # Receive
        recv_guid, recv_payload, addr = receiver.receive_packet(key)

        assert recv_guid == guid
        assert recv_payload == payload
        assert '127.0.0.1' in addr[0]

        sender.close()
        receiver.close()

    def test_multiple_packets(self):
        """Test sending/receiving multiple packets."""
        key = b'\\x00' * 32

        receiver = UDPSocket(port=50021)
        receiver.bind()
        receiver.socket.settimeout(2.0)

        sender = UDPSocket(port=0)
        sender.bind()

        # Send 3 packets
        for i in range(3):
            sender.send_packet(b'\\x01'*6, f'packet {i}'.encode(), key, '127.0.0.1', 50021)

        # Receive 3 packets
        payloads = []
        for i in range(3):
            _, payload, _ = receiver.receive_packet(key)
            payloads.append(payload)

        assert len(payloads) == 3
        assert b'packet 0' in payloads
        assert b'packet 1' in payloads
        assert b'packet 2' in payloads

        sender.close()
        receiver.close()

    def test_invalid_key_rejected(self):
        """Test that packets with wrong key are rejected."""
        send_key = b'\\x00' * 32
        recv_key = b'\\xff' * 32

        receiver = UDPSocket(port=50022)
        receiver.bind()
        receiver.socket.settimeout(1.0)

        sender = UDPSocket(port=0)
        sender.bind()

        sender.send_packet(b'\\x01'*6, b'test', send_key, '127.0.0.1', 50022)

        # Should raise ValueError (invalid packet)
        with pytest.raises(ValueError, match="Invalid packet"):
            receiver.receive_packet(recv_key)

        sender.close()
        receiver.close()

    def test_large_payload(self):
        """Test sending large payload."""
        key = b'\\x00' * 32
        large_payload = b'X' * 10000

        receiver = UDPSocket(port=50023)
        receiver.bind()
        receiver.socket.settimeout(2.0)

        sender = UDPSocket(port=0)
        sender.bind()

        sender.send_packet(b'\\x01'*6, large_payload, key, '127.0.0.1', 50023)

        _, payload, _ = receiver.receive_packet(key, buffer_size=65507)

        assert payload == large_payload

        sender.close()
        receiver.close()
```

### 2. Run Integration Tests

```bash
pytest tests/integration/test_packet_flow.py -v
```

## Verification

- [ ] All integration tests pass
- [ ] Complete flow works
- [ ] Invalid keys rejected
- [ ] Large payloads work

```bash
pytest tests/integration/test_packet_flow.py -v
```
