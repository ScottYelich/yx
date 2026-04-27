// Protocol 1 Test Sender: Base (no compression, no encryption)
// Traceability: specs/testing/interoperability-requirements.md

import Foundation
import YXProtocol

// Protocol 1: Base (no compression, no encryption)
do {
    let data = Data(repeating: 0xCD, count: 100)

    let packets = try SimplePacketBuilder.buildBinaryPackets(
        data: data,
        guid: TestConfig.testGUID,
        key: TestConfig.testKey,
        protoOpts: 0x00, // Base
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
