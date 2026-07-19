import XCTest
import CryptoKit
@testable import YXProtocol

final class UDPSocketTests: XCTestCase {
    func testSocketInit() {
        let socket = UDPSocket(port: 50000)
        XCTAssertEqual(socket.port, 50000)
    }

    func testSendSmallPacket() throws {
        let socket = UDPSocket(port: 0)
        let data = Data("test".utf8)
        // Should not crash - sending to loopback on random port
        try socket.sendPacket(data: data, host: "127.0.0.1", port: 50010)
    }
}
