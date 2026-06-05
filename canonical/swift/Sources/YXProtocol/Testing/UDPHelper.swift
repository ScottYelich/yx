import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Simple UDP send/receive helpers for testing
///
/// Synchronous, blocking operations - suitable for test programs.
///
/// Traceability:
/// - specs/architecture/api-contracts.md § Test Helpers
public struct UDPHelper {

    /// Send UDP packet
    /// - Parameters:
    ///   - packet: Packet data to send
    ///   - host: Destination host
    ///   - port: Destination port
    /// - Throws: UDPError if send fails
    public static func send(packet: Data, to host: String, port: UInt16) throws {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else {
            throw UDPError.socketCreationFailed
        }
        defer {
            close(sock)
        }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian

        guard inet_pton(AF_INET, host, &addr.sin_addr) == 1 else {
            throw UDPError.invalidAddress
        }

        let sent = packet.withUnsafeBytes { buffer in
            withUnsafePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    sendto(sock, buffer.baseAddress, buffer.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        guard sent >= 0 else {
            throw UDPError.sendFailed
        }
    }

    /// Receive UDP packet (blocking, with timeout)
    /// - Parameters:
    ///   - port: Port to bind to
    ///   - timeout: Receive timeout in seconds (default 5.0)
    /// - Returns: Received packet data and source address
    /// - Throws: UDPError if receive fails
    public static func receive(port: UInt16, timeout: TimeInterval = 5.0) throws -> (data: Data, sourceAddr: String, sourcePort: UInt16) {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else {
            throw UDPError.socketCreationFailed
        }
        defer {
            close(sock)
        }

        // Allow rapid rebind during sequential interop test runs.
        var reuseVal: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuseVal, socklen_t(MemoryLayout<Int32>.size))

        // Set receive timeout
        var tv = timeval()
        tv.tv_sec = Int(timeout)
        tv.tv_usec = Int32((timeout.truncatingRemainder(dividingBy: 1.0)) * 1_000_000)

        guard setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size)) >= 0 else {
            throw UDPError.socketOptionFailed
        }

        // Bind socket
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(sock, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult >= 0 else {
            throw UDPError.bindFailed
        }

        // Receive packet
        var buffer = [UInt8](repeating: 0, count: 65536)
        var srcAddr = sockaddr_in()
        var srcAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

        let received = withUnsafeMutablePointer(to: &srcAddr) { srcAddrPtr in
            srcAddrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                recvfrom(sock, &buffer, buffer.count, 0, sockaddrPtr, &srcAddrLen)
            }
        }

        guard received > 0 else {
            throw UDPError.receiveFailed
        }

        let data = Data(buffer.prefix(received))

        // Extract source address
        var srcAddrStr = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &srcAddr.sin_addr, &srcAddrStr, socklen_t(INET_ADDRSTRLEN))
        let sourceAddr = String(cString: srcAddrStr)
        let sourcePort = UInt16(bigEndian: srcAddr.sin_port)

        return (data, sourceAddr, sourcePort)
    }

    /// Bind a UDP socket once for repeated receives. Required for multi-chunk
    /// messages: the one-shot `receive` binds+closes per call, which drops
    /// chunks that arrive during the close/reopen window when the sender does
    /// not delay between packets.
    /// - Returns: a bound socket file descriptor (close with `closeReceiver`)
    public static func bindReceiver(port: UInt16, timeout: TimeInterval = 5.0) throws -> Int32 {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { throw UDPError.socketCreationFailed }

        var reuseVal: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuseVal, socklen_t(MemoryLayout<Int32>.size))

        var tv = timeval()
        tv.tv_sec = Int(timeout)
        tv.tv_usec = Int32((timeout.truncatingRemainder(dividingBy: 1.0)) * 1_000_000)
        guard setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size)) >= 0 else {
            close(sock)
            throw UDPError.socketOptionFailed
        }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(sock, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult >= 0 else {
            close(sock)
            throw UDPError.bindFailed
        }
        return sock
    }

    /// Receive one datagram on an already-bound socket (see `bindReceiver`).
    public static func receiveOn(_ sock: Int32) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: 65536)
        let received = recvfrom(sock, &buffer, buffer.count, 0, nil, nil)
        guard received > 0 else { throw UDPError.receiveFailed }
        return Data(buffer.prefix(received))
    }

    /// Close a socket returned by `bindReceiver`.
    public static func closeReceiver(_ sock: Int32) {
        close(sock)
    }
}

/// UDP helper errors
public enum UDPError: Error, CustomStringConvertible {
    case socketCreationFailed
    case invalidAddress
    case bindFailed
    case sendFailed
    case receiveFailed
    case socketOptionFailed
    case timeout

    public var description: String {
        switch self {
        case .socketCreationFailed:
            return "Failed to create socket"
        case .invalidAddress:
            return "Invalid address"
        case .bindFailed:
            return "Failed to bind socket"
        case .sendFailed:
            return "Failed to send packet"
        case .receiveFailed:
            return "Failed to receive packet"
        case .socketOptionFailed:
            return "Failed to set socket option"
        case .timeout:
            return "Receive timeout"
        }
    }
}
