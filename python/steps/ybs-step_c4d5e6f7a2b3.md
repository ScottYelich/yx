# Step 9: Integration Tests

**Version**: 0.1.0

## Overview

Create end-to-end integration tests that verify complete YX packet workflow.

## What This Step Builds

Builds end-to-end integration tests verifying the full packet lifecycle: `build → serialize → UDP send → UDP receive → parse → HMAC validate`. Uses real loopback UDP sockets.

## Step Objectives

1. Test complete build → send → receive → validate flow
2. Test multiple packet exchanges
3. Test with different keys, GUIDs, payloads
4. Integration test coverage

## Prerequisites

- Step 8 completed

## Traceability

**Implements**: protocol/specs/testing/testing-strategy.md § Category 5: Integration Tests

## Instructions

### Before Starting — Record Start Time

Record the current timestamp in ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`
This is used for duration calculation in the DONE file.

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

## Documentation

**Record end time** and calculate duration (end − start timestamp).

Create `docs/build-history/ybs-step_c4d5e6f7a2b3-DONE.txt`:

```
STEP ybs-step_c4d5e6f7a2b3: Integration Tests
STARTED:    [start timestamp from Before Starting]
COMPLETED:  [ISO 8601 timestamp]
DURATION:   [minutes]

OBJECTIVES COMPLETED:
[copy from Step Objectives above]

FILES CREATED/MODIFIED:
- tests/integration/test_packet_flow.py

VERIFICATION: PASSED (attempt [N])

NEXT STEP: ybs-step_d5e6f7a2b3c4 (Generate Canonical Artifacts)
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
- **Next**: `ybs-step_d5e6f7a2b3c4` — Generate Canonical Artifacts

## Version History

### 0.1.0 (2026-04-11)
- Initial step creation
