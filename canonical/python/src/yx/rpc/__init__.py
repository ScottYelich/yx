"""
RPC subsystem for JSON-RPC 2.0 support.

Traceability:
- protocol/specs/architecture/protocol-layers.md (Protocol 0 section)
"""

from .json_rpc import RPCRequest, RPCResponse, RPCError
from .dispatcher import RPCDispatcher

__all__ = ['RPCRequest', 'RPCResponse', 'RPCError', 'RPCDispatcher']
