// Protocol 0 Test Sender: Large JSON payload
// Traceability: specs/testing/interoperability-requirements.md

import Foundation
import YXProtocol

// Protocol 0: Large JSON payload
do {
    struct RPCRequest: Codable {
        let jsonrpc: String
        let method: String
        let params: [String: String]
        let id: Int
    }

    // Large params (1000 key-value pairs)
    var largeParams: [String: String] = [:]
    for i in 0..<1000 {
        largeParams["key\(i)"] = "value\(i)"
    }

    let request = RPCRequest(
        jsonrpc: "2.0",
        method: "test.large",
        params: largeParams,
        id: 2
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
