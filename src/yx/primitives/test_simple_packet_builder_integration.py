"""
Integration test: Build -> Send -> Receive using SimplePacketBuilder.

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
