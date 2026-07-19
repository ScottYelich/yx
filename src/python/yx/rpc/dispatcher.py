"""
JSON-RPC 2.0 dispatcher

Handles JSON-RPC method dispatch matching Swift RPCDispatcher.
"""

import asyncio
from typing import Dict, Callable, Awaitable, Optional, Any
from dataclasses import dataclass
from ..primitives.logger import Logger

logger = Logger("RPCDispatcher")


@dataclass
class RPCRequest:
    """JSON-RPC 2.0 request"""
    id: Optional[Any]
    method: str
    params: Dict[str, Any]
    raw: Dict[str, Any]

    def reply(self, result: Any = None, error: Optional[Dict] = None):
        """Helper to construct response (to be sent by caller)"""
        return RPCResponse(id=self.id, result=result, error=error)


@dataclass
class RPCResponse:
    """JSON-RPC 2.0 response"""
    id: Optional[Any]
    result: Optional[Any] = None
    error: Optional[Dict] = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to JSON-RPC response dict"""
        response = {"jsonrpc": "2.0", "id": self.id}
        if self.error:
            response["error"] = self.error
        else:
            response["result"] = self.result
        return response


class RPCDispatcher:
    """JSON-RPC 2.0 method dispatcher"""

    def __init__(self):
        """Initialize dispatcher"""
        self.handlers: Dict[str, Callable[[RPCRequest], Awaitable[None]]] = {}

    def register(self, method: str, handler: Callable[[RPCRequest], Awaitable[None]]):
        """
        Register RPC method handler.

        Args:
            method: Method name (e.g., "task.hello")
            handler: Async handler function
        """
        self.handlers[method] = handler
        logger.info(f"Registered RPC handler: {method}")

    async def dispatch(self, message: Dict[str, Any]):
        """
        Dispatch JSON-RPC message to handler.

        Args:
            message: JSON-RPC message dict
        """
        try:
            # Parse request
            method = message.get("method")
            params = message.get("params", {})
            req_id = message.get("id")

            if not method:
                logger.error("Missing method in RPC request")
                return

            # Create request object
            request = RPCRequest(id=req_id, method=method, params=params, raw=message)

            # Find handler
            handler = self.handlers.get(method)
            if not handler:
                logger.warning(f"No handler for method: {method}")
                return

            # Dispatch
            logger.info(f"Dispatching RPC: {method}")
            await handler(request)

        except Exception as e:
            logger.error(f"RPC dispatch error: {e}")
