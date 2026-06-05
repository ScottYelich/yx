// Protocol 0 Test Sender: Simple JSON-RPC
// Traceability: specs/testing/interoperability-requirements.md

import Foundation
import YXProtocol

// Protocol 0: Simple JSON-RPC
do {
    struct RPCRequest: Codable {
        let jsonrpc: String
        let method: String
        let params: [String: String]
        let id: Int
    }

    let request = RPCRequest(
        jsonrpc: "2.0",
        method: "test.echo",
        params: ["message": "Hello from Swift"],
        id: 1
    )

    let packet = try SimplePacketBuilder.buildTextPacket(
        message: request,
        guid: TestConfig.testGUID,
        key: TestConfig.testKey
    )

    try UDPHelper.send(packet: packet, to: TestConfig.testHost, port: TestConfig.testPort)

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
