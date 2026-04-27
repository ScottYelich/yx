// Protocol 1 Test Sender: Encrypted (AES-256-GCM)
// Traceability: specs/testing/interoperability-requirements.md

import Foundation
import YXProtocol

// Protocol 1: Encrypted (AES-256-GCM)
do {
    let data = Data(repeating: 0xFF, count: 100)

    let packets = try SimplePacketBuilder.buildBinaryPackets(
        data: data,
        guid: TestConfig.testGUID,
        key: TestConfig.testKey,
        protoOpts: 0x02, // Encrypted
        encryptionKey: TestConfig.testEncryptionKey,
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
