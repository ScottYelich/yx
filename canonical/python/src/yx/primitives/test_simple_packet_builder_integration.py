r"""
Integration test: Build packet with SimplePacketBuilder, send, receive with full framework.

Traceability:
- protocol/specs/testing/interoperability-requirements.md (Test Pattern)
"""

import pytest
import asyncio
import os
from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packet, TestConfig
from yx.transport.udp_socket import UDPSocket
from yx.transport.packet_builder import PacketBuilder


@pytest.mark.asyncio
async def test_simple_packet_builder_integration():
    """
   Integration test: Build + send + receive.

   Pattern:
   1. Create receiver (full framework)
   2. Build packet with SimplePacketBuilder
   3. Send packet
   4. Verify receiver gets it
   """
   guid = TestConfig.test_guid()
   key = TestConfig.test_key()
   port = TestConfig.test_port()

   received = []

   # Start receiver
   receiver = UDPSocket(port=port)

   async def receive_task() -> None:
     try:
       data, addr = receiver.receive_packet(timeout=2.0)
       packet = PacketBuilder.parse_packet(data)
       if PacketBuilder.validate_hmac(packet, key, addr):
         received.append(packet.payload)
     except Exception as e:
       pass  # Timeout expected

   receive_future = asyncio.create_task(receive_task())

   # Wait for receiver to bind
   await asyncio.sleep(0.1)

   # Build and send packet
   message = {"method": "test", "params": {"value": 42}}
   packet = SimplePacketBuilder.build_text_packet(message, guid, key)
   send_udp_packet(packet, "127.0.0.1", port)

   # Wait for receive
   await receive_future

   # Verify
   assert len(received) == 1
   assert received[0][0] == 0x00  # Protocol 0

   # Cleanup
   receiver.close()
