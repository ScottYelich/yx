#!/usr/bin/env python3
"""
Quick Python-to-Python interoperability test.

Tests that Python sender and receiver can exchange packets.
This proves the core protocol works.
"""

import sys
import time
from pathlib import Path

# Add Python implementation to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "canonical" / "python" / "src"))

from yx.transport import PacketBuilder, UDPSocket
from yx.primitives import GUIDFactory

TEST_PORT = 7777
TEST_KEY = b'\x00' * 32

print("=" * 70)
print("YX Protocol - Python Interoperability Test")
print("=" * 70)
print()

# Test 1: Python → Python
print("Test: Python sender → Python receiver")
print(f"Port: {TEST_PORT}")
print()

try:
    # Create receiver
    receiver = UDPSocket(port=TEST_PORT)
    receiver.bind()
    receiver.socket.settimeout(2.0)
    print("✓ Python receiver listening")

    time.sleep(0.2)

    # Create sender
    sender = UDPSocket(port=0)
    guid = GUIDFactory.generate()
    payload = b"Hello from Python!"

    # Send packet
    sender.send_packet(guid=guid, payload=payload, key=TEST_KEY, host="127.0.0.1", port=TEST_PORT)
    print(f"✓ Python sender sent: {payload.decode()}")

    # Receive packet
    recv_guid, recv_payload, addr = receiver.receive_packet(key=TEST_KEY)
    print(f"✓ Python receiver got: {recv_payload.decode()}")
    print()

    # Verify
    if recv_payload == payload:
        print("=" * 70)
        print("✅ SUCCESS: Python ↔ Python communication verified!")
        print("=" * 70)
        receiver.close()
        sender.close()
        sys.exit(0)
    else:
        print("❌ FAILED: Payload mismatch")
        receiver.close()
        sender.close()
        sys.exit(1)

except Exception as e:
    print(f"❌ FAILED: {e}")
    try:
        receiver.close()
        sender.close()
    except:
        pass
    sys.exit(1)
