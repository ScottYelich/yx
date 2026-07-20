"""
YX Coordinator - Main composition root

Coordinates all YX subsystems matching Swift CommsCoordinator.
"""

import asyncio
from typing import Optional, Callable, Awaitable
from ..primitives.guid import GUIDFactory, guid_to_hex
from ..primitives.data_crypto import generate_key
from ..primitives.logger import Logger
from ..transport.udp_transport import UDPTransport
from ..transport.key_store import KeyStore
from ..transport.rate_limiter import RateLimiter
from ..transport.protocol_router import ProtocolRouter, ProtocolID
from ..transport.text_protocol import TextProtocol
from ..transport.binary_protocol import BinaryProtocol
from ..rpc.dispatcher import RPCDispatcher
from .configuration import YXConfiguration

logger = Logger("YXCoordinator")


class YXCoordinator:
    """Main coordinator for YX framework"""

    def __init__(
        self,
        guid: bytes,
        key: bytes,
        config: Optional[YXConfiguration] = None,
        on_text_message: Optional[Callable[[dict], Awaitable[None]]] = None
    ):
        """
        Initialize YX coordinator.

        Args:
            guid: 6-byte GUID
            key: 32-byte symmetric key
            config: Configuration (default if None)
            on_text_message: Callback for text protocol messages
        """
        self.guid = guid
        self.key = key
        self.config = config or YXConfiguration.default()
        self.on_text_message = on_text_message

        # Initialize subsystems
        self.key_store = KeyStore(key)
        self.rate_limiter = RateLimiter(
            max_requests=self.config.security.max_requests_per_window,
            window_seconds=self.config.security.rate_limit_window
        )

        # RPC dispatcher (create first so protocols can use it)
        self.rpc_dispatcher = RPCDispatcher()

        # Protocol handlers - use RPC dispatcher as default callback
        async def dispatch_to_rpc(message: dict):
            """Dispatch messages to RPC dispatcher"""
            await self.rpc_dispatcher.dispatch(message)

        # Allow custom on_text_message or default to RPC dispatcher
        message_callback = on_text_message if on_text_message else dispatch_to_rpc

        self.text_protocol = TextProtocol(message_callback)
        self.binary_protocol = BinaryProtocol(
            key,
            chunk_size=self.config.protocol.chunk_size,
            buffer_timeout=self.config.protocol.buffer_timeout,
            on_message=message_callback  # Binary protocol also dispatches to RPC
        )

        # Protocol router
        self.protocol_router = ProtocolRouter()
        self.protocol_router.register(ProtocolID.TEXT, self.text_protocol.handle)
        self.protocol_router.register(ProtocolID.BINARY, self.binary_protocol.handle)

        # Register default handlers
        self._register_default_handlers()

        # UDP transport
        self.udp_transport = UDPTransport(
            guid=guid,
            key_store=self.key_store,
            rate_limiter=self.rate_limiter,
            port=self.config.network.udp_port,
            process_own_packets=self.config.network.process_own_packets
        )

        logger.guid(f"GUID: {guid_to_hex(guid)}")
        logger.key(f"Key: {self.key.hex().upper()}")

    def _register_default_handlers(self):
        """Register default RPC handlers"""
        async def handle_hello(request):
            name = request.params.get("name", "Unknown")
            logger.info(f"Received hello from: {name}")

        self.rpc_dispatcher.register("task.hello", handle_hello)

    async def start(self):
        """Start YX coordinator"""
        await self.udp_transport.start(self._on_packet)
        logger.success("YX Coordinator started")

    async def stop(self):
        """Stop YX coordinator"""
        await self.udp_transport.stop()
        logger.info("YX Coordinator stopped")

    async def _on_packet(self, guid: bytes, payload: bytes, addr):
        """Handle received packet"""
        # Route to protocol handler
        await self.protocol_router.route(payload)

    def register_sexp(self, head, handler):
        """Register an S-expression handler for a car (head) symbol (ADR D11)."""
        self.text_protocol.register_sexp(head, handler)

    async def send_sexpr_packet(self, expr, host: str, port: int):
        """
        Send an S-expression as a Protocol-0 text payload (ADR D11).

        Args:
            expr: SExpr to send (serialized to its light canonical form)
            host: Destination host
            port: Destination port
        """
        payload = expr.serialize().encode("utf-8")
        await self.udp_transport.send(payload, host, port)
        logger.send(f"Sent s-expr packet to {host}:{port}")

    async def send_text_packet(self, message: dict, host: str, port: int):
        """
        Send text protocol packet.

        Args:
            message: JSON message
            host: Destination host
            port: Destination port
        """
        payload = await self.text_protocol.send(message)
        await self.udp_transport.send(payload, host, port)
        logger.send(f"Sent text packet to {host}:{port}")

    async def send_binary_packet(self, data: bytes, proto_opts: int, host: str, port: int, channel_id: int = 1):
        """
        Send binary protocol packet(s) (v2.0 with channel support).

        Args:
            data: Binary data
            proto_opts: Protocol options (0x00-0x03)
            host: Destination host
            port: Destination port
            channel_id: Logical channel ID (default: 1)
        """
        payloads = await self.binary_protocol.send(data, proto_opts, channel_id)
        for payload in payloads:
            await self.udp_transport.send(payload, host, port)

    async def send_hello(self, name: str, host: str, port: int):
        """Send task.hello message"""
        await self.send_text_packet(
            {"method": "task.hello", "params": {"name": name}, "id": 1},
            host,
            port
        )
        logger.broadcast(f"Sent task.hello to {host}:{port}")
