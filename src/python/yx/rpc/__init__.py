"""
RPC Module - JSON-RPC 2.0 dispatch system

Provides JSON-RPC dispatcher and handlers matching Swift RPCCore.
"""

from .dispatcher import RPCDispatcher, RPCRequest, RPCResponse

__all__ = ["RPCDispatcher", "RPCRequest", "RPCResponse"]
