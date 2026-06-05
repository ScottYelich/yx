// Protocol 1 Test Sender: Both compressed and encrypted
// Traceability: specs/testing/interoperability-requirements.md

import Foundation
import YXProtocol

// Protocol 1: Both compressed and encrypted
do {
    let data = Data(repeating: 0xAA, count: 1000)

    let packets = try SimplePacketBuilder.buildBinaryPackets(
        data: data,
        guid: TestConfig.testGUID,
        key: TestConfig.testKey,
        protoOpts: 0x03, // Both
        encryptionKey: TestConfig.testKey, // match Python canonical (AES key == test key)
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
