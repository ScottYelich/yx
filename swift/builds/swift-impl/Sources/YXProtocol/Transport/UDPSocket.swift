import Foundation

// Implements: protocol/specs/technical/yx-protocol-spec.md § UDP Transport

public class UDPSocket {
    public let port: UInt16
    private var sockfd: Int32 = -1
    private var timeoutSeconds: Double = 5.0

    public init(port: UInt16 = 50000) {
        self.port = port
    }

    /// Bind socket to the port for receiving.
    public func bind() throws {
        sockfd = socket(AF_INET, SOCK_DGRAM, 0)
        guard sockfd >= 0 else { throw POSIXError(.ENOTSUP) }

        var opt: Int32 = 1
        setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian

        let bindResult = withUnsafePointer(to: addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Foundation.bind(sockfd, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { throw POSIXError(.EADDRINUSE) }
    }

    /// Set receive timeout in seconds.
    public func setTimeout(_ seconds: Double) {
        timeoutSeconds = seconds
        var tv = timeval()
        tv.tv_sec = Int(seconds)
        tv.tv_usec = Int32((seconds - Double(Int(seconds))) * 1_000_000)
        setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    }

    /// Receive one validated YX packet. Returns (guid, payload, senderAddr) or nil on timeout.
    public func receivePacket(key: Data) throws -> (Data, Data, String)? {
        let symKey = try Data.symmetricKey(from: key)
        var buffer = [UInt8](repeating: 0, count: 65536)
        var senderAddr = sockaddr_in()
        var senderAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

        let n = withUnsafeMutablePointer(to: &senderAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                recvfrom(sockfd, &buffer, buffer.count, 0, sockPtr, &senderAddrLen)
            }
        }

        if n <= 0 { return nil } // timeout

        let data = Data(buffer[0..<n])
        guard let packet = PacketBuilder.parseAndValidate(data, key: symKey) else {
            return nil // invalid HMAC
        }

        let addrStr = String(cString: inet_ntoa(senderAddr.sin_addr))
        return (packet.guid, packet.payload, addrStr)
    }

    /// Send data via UDP.
    public func sendPacket(data: Data, host: String = "127.0.0.1", port: UInt16) throws {
        let tempSock = socket(AF_INET, SOCK_DGRAM, 0)
        guard tempSock >= 0 else { throw POSIXError(.ENOTSUP) }
        defer { Darwin.close(tempSock) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr(host)

        try data.withUnsafeBytes { ptr in
            let sent = withUnsafePointer(to: addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddrPtr in
                    sendto(tempSock, ptr.baseAddress, data.count, 0, sockAddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if sent < 0 { throw POSIXError(.ENOTSUP) }
        }
    }

    public func close() {
        if sockfd >= 0 {
            Darwin.close(sockfd)
            sockfd = -1
        }
    }

    deinit {
        close()
    }
}
