"""
YX Configuration

Externalized settings matching Swift YXConfiguration.
"""

from dataclasses import dataclass, field


@dataclass
class NetworkConfig:
    """Network configuration"""
    udp_port: int = 9999
    max_packet_size: int = 4096
    broadcast_address: str = "192.168.1.255"
    process_own_packets: bool = True


@dataclass
class ProtocolConfig:
    """Protocol configuration"""
    chunk_size: int = 1024
    buffer_timeout: float = 60.0
    compression_threshold: int = 65536


@dataclass
class SecurityConfig:
    """Security configuration"""
    max_requests_per_window: int = 100
    rate_limit_window: float = 60.0
    enable_hmac: bool = True
    enable_encryption: bool = True


@dataclass
class YXConfiguration:
    """Complete YX framework configuration"""
    network: NetworkConfig = field(default_factory=NetworkConfig)
    protocol: ProtocolConfig = field(default_factory=ProtocolConfig)
    security: SecurityConfig = field(default_factory=SecurityConfig)

    @classmethod
    def default(cls) -> 'YXConfiguration':
        """Create default configuration"""
        return cls()
