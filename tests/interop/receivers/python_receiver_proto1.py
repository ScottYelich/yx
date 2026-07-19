#! /usr/bin/env python3
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
