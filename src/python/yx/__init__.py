"""
YX Networking Framework - Python Implementation

A production-grade networking framework featuring:
- Actor-based concurrency (asyncio)
- Multi-protocol support (text/JSON and binary/chunked)
- Enterprise-grade security (HMAC-SHA256, AES-GCM, rate limiting)
- JSON-RPC 2.0 dispatch system

Simple API for developers:
    from yx import YX

    yx = YX(port=9999)

    @yx.rpc("hello")
    async def handle_hello(request):
        print(f"Hello from {request.params['name']}")

    await yx.sendText({"method": "hello", "params": {"name": "Scott"}}, "192.168.1.100", 9999)
    await yx.start()
"""

__version__ = "1.0.0"
__author__ = "YX Framework Team"

# High-level simplified API
from .YX import YX

# Supporting classes for advanced usage
from .primitives.guid import GUIDFactory, guid_to_hex
from .rpc.dispatcher import RPCRequest, RPCResponse

# Advanced API (for users who need full control)
from .application.yx_coordinator import YXCoordinator
from .application.configuration import YXConfiguration

__all__ = [
    # Simplified API (recommended)
    'YX',
    'GUIDFactory',
    'guid_to_hex',
    'RPCRequest',
    'RPCResponse',
    # Advanced API
    'YXCoordinator',
    'YXConfiguration',
]
