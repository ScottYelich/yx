import Foundation
// filename: Configuration.swift

import Primitives

/// Configuration for the YX networking system.
///
/// Externalizes all hardcoded values for flexibility and testability.
/// Can be loaded from files, environment variables, or created programmatically.
public struct Configuration: Sendable {

    /// Network-related configuration
    public struct Network: Sendable {
        /// UDP listening port (default: 9999)
        public var udpPort: UInt16

        /// Broadcast address for discovery (default: 255.255.255.255)
        public var broadcastAddress: String

        /// Maximum UDP packet size in bytes (default: 4096)
        public var maxPacketSize: Int

        /// Whether to process packets sent by this instance (default: true)
        public var processOwnPackets: Bool

        public init(
            udpPort: UInt16 = 9999,
            broadcastAddress: String = "255.255.255.255",
            maxPacketSize: Int = 4096,
            processOwnPackets: Bool = true
        ) {
            self.udpPort = udpPort
            self.broadcastAddress = broadcastAddress
            self.maxPacketSize = maxPacketSize
            self.processOwnPackets = processOwnPackets
        }
    }

    /// Protocol-related configuration
    public struct ProtocolSettings: Sendable {
        /// Chunk size for Protocol1 binary messages in bytes (default: 1024)
        public var chunkSize: Int

        /// Compression buffer size in bytes (default: 65536 / 64KB)
        public var compressionBufferSize: Int

        /// Timeout for incomplete message buffers in seconds (default: 60)
        public var bufferTimeout: TimeInterval

        public init(
            chunkSize: Int = 1024,
            compressionBufferSize: Int = 64 * 1024,
            bufferTimeout: TimeInterval = 60.0
        ) {
            self.chunkSize = chunkSize
            self.compressionBufferSize = compressionBufferSize
            self.bufferTimeout = bufferTimeout
        }
    }

    /// Logging configuration
    public struct Logging: Sendable {
        /// Whether logging is enabled (default: true)
        public var enabled: Bool

        /// Minimum log level to display (default: .info)
        public var minimumLevel: LogLevel

        public init(
            enabled: Bool? = nil,
            minimumLevel: LogLevel? = nil
        ) {
            // Read from LOG_LEVEL environment variable if not explicitly set
            let envLogLevel = ProcessInfo.processInfo.environment["LOG_LEVEL"]?.lowercased()

            if let enabled = enabled, let minimumLevel = minimumLevel {
                // Both explicitly provided
                self.enabled = enabled
                self.minimumLevel = minimumLevel
            } else if let envLevel = envLogLevel {
                // Read from environment
                switch envLevel {
                case "silent":
                    self.enabled = false
                    self.minimumLevel = .error
                case "debug":
                    self.enabled = true
                    self.minimumLevel = .debug
                case "market", "info":
                    // Market/info level: disable YX framework debug logs
                    self.enabled = false
                    self.minimumLevel = .error
                default:
                    self.enabled = enabled ?? true
                    self.minimumLevel = minimumLevel ?? .info
                }
            } else {
                // Use defaults
                self.enabled = enabled ?? true
                self.minimumLevel = minimumLevel ?? .info
            }
        }
    }

    /// Security-related configuration
    public struct Security: Sendable {
        /// Whether HMAC validation is enabled (default: true)
        public var hmacEnabled: Bool

        /// Whether encryption is enabled (default: true)
        public var encryptionEnabled: Bool

        /// Whether rate limiting is enabled (default: true)
        public var rateLimitingEnabled: Bool

        /// Maximum requests per peer per window (default: 100)
        public var maxRequestsPerWindow: Int

        /// Rate limiting window duration in seconds (default: 60)
        public var rateLimitWindow: TimeInterval

        /// Whether replay protection is enabled (default: false for backward compatibility)
        public var replayProtectionEnabled: Bool

        /// Maximum age for packet timestamps in seconds (default: 300 / 5 minutes)
        public var maxPacketAge: TimeInterval

        /// How long to remember nonces in seconds (default: 300 / 5 minutes)
        public var nonceCacheDuration: TimeInterval

        public init(
            hmacEnabled: Bool = true,
            encryptionEnabled: Bool = true,
            rateLimitingEnabled: Bool = true,
            maxRequestsPerWindow: Int = 100,
            rateLimitWindow: TimeInterval = 60.0,
            replayProtectionEnabled: Bool = false,
            maxPacketAge: TimeInterval = 300.0,
            nonceCacheDuration: TimeInterval = 300.0
        ) {
            self.hmacEnabled = hmacEnabled
            self.encryptionEnabled = encryptionEnabled
            self.rateLimitingEnabled = rateLimitingEnabled
            self.maxRequestsPerWindow = maxRequestsPerWindow
            self.rateLimitWindow = rateLimitWindow
            self.replayProtectionEnabled = replayProtectionEnabled
            self.maxPacketAge = maxPacketAge
            self.nonceCacheDuration = nonceCacheDuration
        }
    }

    public var network: Network
    public var protocolSettings: ProtocolSettings
    public var security: Security
    public var logging: Logging

    /// Creates a configuration with default values
    public init(
        network: Network = Network(),
        protocolSettings: ProtocolSettings = ProtocolSettings(),
        security: Security = Security(),
        logging: Logging = Logging()
    ) {
        self.network = network
        self.protocolSettings = protocolSettings
        self.security = security
        self.logging = logging
    }

    /// Returns the default configuration
    public static var `default`: Configuration {
        Configuration()
    }
}
