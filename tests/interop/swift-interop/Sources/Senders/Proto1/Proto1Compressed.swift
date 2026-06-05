// Protocol 1 Test Sender: Compressed (ZLIB)
// Traceability: specs/testing/interoperability-requirements.md

import Foundation
import YXProtocol

// Protocol 1: Compressed (ZLIB)
do {
    let data = Data(repeating: 0xEE, count: 1000)

    let packets = try SimplePacketBuilder.buildBinaryPackets(
        data: data,
        guid: TestConfig.testGUID,
        key: TestConfig.testKey,
        protoOpts: 0x01, // Compressed
        channelID: 0,
        sequence: 0
    )

    for packet in packets {
        try UDPHelper.send(packet: packet, to: TestConfig.testHost, port: TestConfig.testPort)
        Thread.sleep(forTimeInterval: 0.01)
    }

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
