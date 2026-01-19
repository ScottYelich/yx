import Testing
import CryptoKit
@testable import YXProtocol

@Suite struct UDPSocketTests {
    @Test func socketInit() {
        let socket = UDPSocket(port: 50000)
        #expect(socket.port == 50000)
    }

    @Test func sendPacket() throws {
        let socket = UDPSocket(port: 0)
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))

        // Should not crash
        try socket.sendPacket(guid: Data(repeating: 0x01, count: 6), payload: Data("test".utf8), key: key, host: "127.0.0.1", port: 50010)
    }
}
