// filename: CommandLineConfig.swift

import Foundation
import CryptoKit
import Primitives

struct PeerTarget {
    let host: String
    let port: UInt16

    init?(string: String) {
        let parts = string.split(separator: ":")
        guard parts.count == 2,
              let port = UInt16(parts[1]) else {
            return nil
        }
        self.host = String(parts[0])
        self.port = port
    }
}

struct CommandLineConfig {
    let guid: Data
    let key: SymmetricKey
    let identityName: String?
    let pubkeysPath: URL?
    let privkeysPath: URL?
    let listenPort: UInt16
    let peers: [PeerTarget]
    let shutdownAfterSeconds: Int?
    let protoOpts: UInt8?
    let payloadSize: Int?

    static func load() -> CommandLineConfig {
        let args = CommandLine.arguments

        // Check for help flags
        if args.contains("-h") || args.contains("--help") {
            printUsage()
            exit(0)
        }

        let guid = GUIDFactory.generate()
        let key = SymmetricKey(data: SHA256.hash(data: Data("shared-secret".utf8)))

        func argValue(_ name: String) -> String? {
            guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
            return args[i + 1]
        }

        // Parse --port (default 50000)
        let listenPort = argValue("--port").flatMap { UInt16($0) } ?? 50000

        // Parse --peers (comma-separated list of host:port)
        let peers: [PeerTarget]
        if let peersStr = argValue("--peers") {
            peers = peersStr.split(separator: ",")
                .compactMap { PeerTarget(string: String($0)) }
        } else {
            peers = []
        }

        // Parse --shutdown-after (seconds)
        let shutdownAfter = argValue("--shutdown-after").flatMap { Int($0) }

        // Parse --proto-opts (0x00-0x03 or decimal 0-3)
        let protoOpts: UInt8?
        if let optsStr = argValue("--proto-opts") {
            if optsStr.hasPrefix("0x") {
                protoOpts = UInt8(optsStr.dropFirst(2), radix: 16)
            } else {
                protoOpts = UInt8(optsStr)
            }
        } else {
            protoOpts = nil
        }

        // Parse --payload-size (in bytes)
        let payloadSize = argValue("--payload-size").flatMap { Int($0) }

        return CommandLineConfig(
            guid: guid,
            key: key,
            identityName: argValue("--identity"),
            pubkeysPath: argValue("--pubkeys").flatMap { URL(fileURLWithPath: $0) },
            privkeysPath: argValue("--privkeys").flatMap { URL(fileURLWithPath: $0) },
            listenPort: listenPort,
            peers: peers,
            shutdownAfterSeconds: shutdownAfter,
            protoOpts: protoOpts,
            payloadSize: payloadSize
        )
    }

    static func printUsage() {
        print("""
        yxCLI - YX Network Protocol Test Tool

        USAGE:
            yxCLI [OPTIONS]

        OPTIONS:
            -h, --help
                Show this help message and exit

            --port <port>
                UDP port to listen on (default: 50000)

            --peers <host:port>[,<host:port>,...]
                Comma-separated list of peers to send packets to
                Example: --peers localhost:50000,192.168.1.100:50000
                If not specified, broadcasts to 192.168.1.255:50000

            --proto-opts <value>
                Protocol 1 options for binary packet testing (hex or decimal)
                Values:
                  0x00 or 0 = Plaintext, Uncompressed
                  0x01 or 1 = Plaintext, Compressed
                  0x02 or 2 = Encrypted, Uncompressed
                  0x03 or 3 = Encrypted, Compressed
                If not specified, sends Protocol 0 text packet (task.hello)

            --payload-size <bytes>
                Size of binary payload to send (in bytes)
                Only used with --proto-opts
                Values > 1024 will result in multiple UDP packets
                Example: --payload-size 5000 (sends ~5 packets with default chunk size)
                If not specified, sends small test message (~300 bytes)

            --shutdown-after <seconds>
                Automatically shutdown after specified seconds
                If not specified, runs indefinitely (use Ctrl+C to stop)

            --identity <name>
                Identity name for PKI operations (optional)

            --pubkeys <path>
                Path to public keys directory (optional)

            --privkeys <path>
                Path to private keys directory (optional)

        EXAMPLES:
            # Run with defaults (text packet broadcast, port 50000)
            yxCLI

            # Test binary protocol with encrypted+compressed option
            yxCLI --proto-opts 0x03 --peers localhost:50000 --shutdown-after 5

            # Test plaintext compressed to specific peer
            yxCLI --proto-opts 0x01 --peers 192.168.1.100:50000

            # Send large binary payload (multiple packets)
            yxCLI --proto-opts 0x02 --payload-size 5000 --peers localhost:50000

            # Test multi-packet encrypted+compressed
            yxCLI --proto-opts 0x03 --payload-size 10000 --peers localhost:50000 --shutdown-after 5

            # Custom port with auto-shutdown
            yxCLI --port 8888 --shutdown-after 10

            # Multiple peers (all listening on same port, filtered by GUID)
            yxCLI --peers localhost:50000,192.168.1.100:50000,192.168.1.101:50000
        """)
    }
}
