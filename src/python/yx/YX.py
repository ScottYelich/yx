"""
Simplified YX Framework API

This module provides a high-level, developer-friendly API for the YX networking framework.
Instead of manually wiring YXCoordinator, protocols, and RPC dispatchers, use this simple facade.

Example:
    from yx import YX

    async def main():
        # Initialize with auto-generated GUID and key
        yx = YX(port=9999)

        # Register RPC handler via decorator
        @yx.rpc("hello")
        async def handle_hello(request):
            print(f"Hello from {request.params['name']}")

        # Or register directly
        yx.register_rpc("ping", handle_ping)

        # Send messages
        await yx.sendText({"method": "hello", "params": {"name": "Scott"}}, "192.168.1.100", 9999)
        await yx.sendBinary(b"data", "192.168.1.100", 9999, encrypt=True, compress=True)

        # Start listening (runs until interrupted or timeout)
        await yx.start(timeout=30)
"""

import asyncio
import signal
from typing import Optional, Union, Callable, Awaitable, Dict, Any
from functools import wraps

from .primitives.guid import GUIDFactory, guid_to_hex
from .primitives.data_crypto import generate_key
from .primitives.logger import Logger
from .application.yx_coordinator import YXCoordinator
from .application.configuration import YXConfiguration
from .rpc.dispatcher import RPCRequest


logger = Logger("YX")


class YX:
    """
    Simplified YX framework API.

    This class wraps YXCoordinator to provide a clean, developer-friendly interface
    for sending/receiving messages and registering RPC handlers.
    """

    def __init__(
        self,
        port: int = 9999,
        guid: Optional[bytes] = None,
        key: Optional[Union[bytes, str]] = None,
        listen_ip: str = "0.0.0.0",
        process_own_packets: bool = False
    ):
        """
        Initialize YX framework.

        Args:
            port: UDP port to listen on (default: 9999)
            guid: 6-byte GUID (auto-generated if None)
            key: 32-byte key as bytes or 64-char hex string (auto-generated if None)
            listen_ip: IP address to bind to (default: 0.0.0.0 for all interfaces)
            process_own_packets: Whether to process packets from self (default: False)
        """
        # Auto-generate GUID if not provided
        if guid is None:
            guid = GUIDFactory.generate()
            logger.info(f"Auto-generated GUID: {guid_to_hex(guid)}")

        # Auto-generate or parse key
        if key is None:
            key = generate_key(256)
            logger.info("Auto-generated symmetric key")
        elif isinstance(key, str):
            # Parse hex string
            key = bytes.fromhex(key)
            if len(key) != 32:
                raise ValueError(f"Key must be 32 bytes, got {len(key)}")

        # Validate inputs
        if len(guid) != 6:
            raise ValueError(f"GUID must be 6 bytes, got {len(guid)}")
        if len(key) != 32:
            raise ValueError(f"Key must be 32 bytes, got {len(key)}")

        # Store for public access
        self.guid = guid
        self.key = key
        self.port = port

        # Create configuration
        config = YXConfiguration.default()
        config.network.udp_port = port
        config.network.process_own_packets = process_own_packets

        # Initialize coordinator
        self._coordinator = YXCoordinator(
            guid=guid,
            key=key,
            config=config
        )

        # Track if started
        self._running = False
        self._stop_event = asyncio.Event()

        logger.success(f"YX initialized on port {port}")
        logger.guid(f"GUID: {guid_to_hex(guid)}")

    def rpc(self, method: str) -> Callable:
        """
        Decorator for registering RPC handlers.

        Example:
            @yx.rpc("hello")
            async def handle_hello(request):
                print(f"Hello from {request.params['name']}")

        Args:
            method: JSON-RPC method name (e.g., "task.hello")

        Returns:
            Decorator function
        """
        def decorator(func: Callable[[RPCRequest], Awaitable[None]]) -> Callable:
            self._coordinator.rpc_dispatcher.register(method, func)
            logger.info(f"Registered RPC handler: {method}")
            return func
        return decorator

    def register_rpc(
        self,
        method: str,
        handler: Callable[[RPCRequest], Awaitable[None]]
    ):
        """
        Register an RPC handler directly (non-decorator style).

        Args:
            method: JSON-RPC method name (e.g., "task.hello")
            handler: Async function that takes RPCRequest
        """
        self._coordinator.rpc_dispatcher.register(method, handler)
        logger.info(f"Registered RPC handler: {method}")

    async def sendText(
        self,
        message: Dict[str, Any],
        host: str,
        port: int
    ):
        """
        Send a text protocol message (JSON-RPC).

        Args:
            message: JSON-RPC message dict (must have "method" key)
            host: Destination IP address (use "255.255.255.255" for broadcast)
            port: Destination port

        Example:
            await yx.sendText(
                {"method": "hello", "params": {"name": "Scott"}, "id": 1},
                "192.168.1.100",
                9999
            )
        """
        await self._coordinator.send_text_packet(message, host, port)
        logger.send(f"Sent text message to {host}:{port}")

    async def sendBinary(
        self,
        data: bytes,
        host: str,
        port: int,
        encrypt: bool = False,
        compress: bool = False,
        channel_id: int = 1
    ):
        """
        Send a binary protocol message (v2.0 with channel support).

        Args:
            data: Binary data to send
            host: Destination IP address (use "255.255.255.255" for broadcast)
            port: Destination port
            encrypt: Whether to encrypt with AES-256-GCM (default: False)
            compress: Whether to compress with zlib (default: False)
            channel_id: Logical channel ID 0-65535 (default: 1)

        Example:
            await yx.sendBinary(
                b"Binary data here",
                "192.168.1.100",
                9999,
                encrypt=True,
                compress=True,
                channel_id=1
            )
        """
        # Map encrypt/compress to proto_opts bitfield
        proto_opts = 0x00
        if compress:
            proto_opts |= 0x01  # Bit 0: compression
        if encrypt:
            proto_opts |= 0x02  # Bit 1: encryption

        await self._coordinator.send_binary_packet(data, proto_opts, host, port, channel_id)
        logger.send(f"Sent binary message to {host}:{port} ch={channel_id} (encrypt={encrypt}, compress={compress})")

    async def start(self, timeout: Optional[float] = None):
        """
        Start listening for incoming messages.

        This will run indefinitely until interrupted (Ctrl+C) or the timeout expires.

        Args:
            timeout: Optional timeout in seconds (None = run forever)

        Example:
            # Run for 30 seconds
            await yx.start(timeout=30)

            # Run until Ctrl+C
            await yx.start()
        """
        if self._running:
            logger.warning("YX is already running")
            return

        # Set up signal handlers
        def signal_handler(sig, frame):
            logger.info("Received interrupt signal, shutting down...")
            self._stop_event.set()

        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)

        # Start coordinator
        await self._coordinator.start()
        self._running = True

        logger.success("YX started, listening for messages...")

        # Wait for stop event or timeout
        try:
            if timeout:
                await asyncio.wait_for(self._stop_event.wait(), timeout=timeout)
                logger.timer(f"Timeout after {timeout} seconds")
            else:
                await self._stop_event.wait()
        except asyncio.TimeoutError:
            pass
        finally:
            await self.stop()

    async def stop(self):
        """
        Stop the YX framework gracefully.

        This will stop listening for messages and clean up resources.
        """
        if not self._running:
            return

        logger.info("Stopping YX...")
        await self._coordinator.stop()
        self._running = False
        logger.success("YX stopped")

    @property
    def guid_hex(self) -> str:
        """Return GUID as hex string for display"""
        return guid_to_hex(self.guid)

    @property
    def key_hex(self) -> str:
        """Return key as hex string for display"""
        return self.key.hex().upper()
