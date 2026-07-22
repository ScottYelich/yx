"""
Primitives Module - Foundation utilities for YX framework

Provides core data manipulation, cryptography, compression, and utility functions.
"""

from .guid import GUIDFactory, guid_to_hex, hex_to_guid
from .data_crypto import compute_hmac, encrypt_aes_gcm, decrypt_aes_gcm, generate_key
from .data_compression import compress_data, decompress_data
from .data_chunking import chunk_data, unchunk_data
from .data_hex import bytes_to_hex, hex_to_bytes
from .logger import Logger
from .operation_result import OperationResult, Success, Failure
from .sexpr import SExpr
from .sexpr_sign import canonical_msg_bytes
from . import signer
from . import trusted_signers
from .test_helpers import TestConfig, SimplePacketBuilder, send_udp_packet, send_udp_packets

__all__ = [
    "SExpr",
    "canonical_msg_bytes",
    "signer",
    "trusted_signers",
    "TestConfig",
    "SimplePacketBuilder",
    "send_udp_packet",
    "send_udp_packets",
    "GUIDFactory",
    "guid_to_hex",
    "hex_to_guid",
    "compute_hmac",
    "encrypt_aes_gcm",
    "decrypt_aes_gcm",
    "generate_key",
    "compress_data",
    "decompress_data",
    "chunk_data",
    "unchunk_data",
    "bytes_to_hex",
    "hex_to_bytes",
    "Logger",
    "OperationResult",
    "Success",
    "Failure",
]
