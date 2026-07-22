"""
UDP transport implementation using asyncio

Provides async UDP socket operations matching Swift UDPNetworkingActor.
"""

import asyncio
import socket
from typing import Optional, Callable, Awaitable, Tuple
from ..primitives.logger import Logger
from ..primitives.guid import guid_to_hex
from .packet_builder import PacketBuilder
from .key_store import KeyStore
from .rate_limiter import RateLimiter
from .replay_protection import ReplayProtection

logger = Logger("UDPTransport")


class UDPTransport:
    """Async UDP transport with packet parsing and security"""

    def __init__(
        self,
        guid: bytes,
        key_store: KeyStore,
        rate_limiter: Optional[RateLimiter] = None,
        replay_protection: Optional[ReplayProtection] = None,
        port: int = 50000,
        process_own_packets: bool = False
    ):
        """
        Initialize UDP transport.

        Args:
            guid: Local GUID (6 bytes)
            key_store: Key store for per-peer keys
            rate_limiter: Optional rate limiter
            replay_protection: Optional replay protection (default: 300s nonce expiry)
            port: UDP port to listen on
            process_own_packets: Whether to process packets from self
        """
        self.guid = guid
        self.key_store = key_store
        self.rate_limiter = rate_limiter or RateLimiter()
        self.replay_protection = replay_protection or ReplayProtection()
        self.port = port
        self.process_own_packets = process_own_packets

        self.socket: Optional[socket.socket] = None
        self.transport: Optional[asyncio.DatagramTransport] = None
        self.protocol: Optional['UDPProtocol'] = None
        self._running = False

    async def start(self, on_packet: Callable[[bytes, bytes, Tuple[str, int]], Awaitable[None]]):
        """
        Start UDP transport.

        Args:
            on_packet: Callback for received packets (guid, payload, addr)
        """
        loop = asyncio.get_event_loop()

        # Create socket with SO_REUSEADDR and SO_REUSEPORT to allow multiple
        # programs to bind to the same IP:port for broadcast reception
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        # SO_REUSEPORT is macOS/Linux only
        if hasattr(socket, 'SO_REUSEPORT'):
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        # Enable broadcast
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.bind(('0.0.0.0', self.port))
        sock.setblocking(False)
        self.socket = sock

        # Create UDP endpoint with pre-configured socket
        self.transport, self.protocol = await loop.create_datagram_endpoint(
            lambda: UDPProtocol(self, on_packet),
            sock=sock
        )

        self._running = True
        logger.network(f"UDP listening on port {self.port}")

    async def stop(self):
        """Stop UDP transport"""
        self._running = False
        if self.transport:
            self.transport.close()
        logger.info("UDP transport stopped")

    async def send(self, payload: bytes, host: str, port: int):
        """
        Send packet.

        Args:
            payload: Packet payload
            host: Destination host
            port: Destination port
        """
        if not self.transport:
            logger.error("Transport not started")
            return

        try:
            # Build packet with HMAC
            packet_bytes = PacketBuilder.build_and_serialize(
                self.guid,
                payload,
                self.key_store.default_key
            )

            # Send
            self.transport.sendto(packet_bytes, (host, port))
            logger.send(f"Sent packet to {host}:{port}")

        except Exception as e:
            logger.error(f"Failed to send packet: {e}")


class UDPProtocol(asyncio.DatagramProtocol):
    """asyncio protocol handler for UDP"""

    def __init__(self, transport: UDPTransport, on_packet: Callable):
        self.transport_obj = transport
        self.on_packet = on_packet

    def connection_made(self, transport):
        """Called when connection is established"""
        pass

    def datagram_received(self, data: bytes, addr: Tuple[str, int]):
        """
        Called when datagram is received.

        Args:
            data: Raw packet bytes
            addr: Source address (host, port)
        """
        asyncio.create_task(self._handle_packet(data, addr))

    async def _handle_packet(self, data: bytes, addr: Tuple[str, int]):
        """Async packet handler"""
        try:
            # Parse packet
            packet = PacketBuilder.parse_packet(data)
            if not packet:
                logger.error("Failed to parse packet")
                return

            # Check if from self
            if packet.guid == self.transport_obj.guid and not self.transport_obj.process_own_packets:
                return  # Ignore own packets

            # Get peer-specific key
            peer_id = guid_to_hex(packet.guid)
            key = self.transport_obj.key_store.get_key(peer_id)

            # Validate HMAC
            if not PacketBuilder.validate_hmac(packet, key, source_addr=addr):
                logger.error(f"HMAC validation failed from {peer_id} at {addr[0]}:{addr[1]}")
                return

            # Replay protection (use HMAC as nonce)
            nonce = data[:16]  # First 16 bytes = HMAC
            if not self.transport_obj.replay_protection.check_and_record(nonce):
                logger.warning(f"Replay attack detected from {peer_id} at {addr[0]}:{addr[1]}")
                return

            # Rate limiting (source_addr passed for logging/diagnostics)
            if not self.transport_obj.rate_limiter.check_rate_limit(peer_id, source_addr=addr):
                logger.warning(f"Rate limited {peer_id}")
                return

            # Dispatch to handler
            await self.on_packet(packet.guid, packet.payload, addr)

        except Exception as e:
            logger.error(f"Error handling packet: {e}")

    def error_received(self, exc):
        """Called on error"""
        logger.error(f"UDP error: {exc}")
