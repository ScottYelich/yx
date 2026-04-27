// Protocol 1 Receiver - handles chunked binary messages
// Traceability: specs/testing/interoperability-requirements.md

import Foundation
import YXProtocol
import CryptoKit

// Message buffer for reassembling chunks
actor MessageBuffer {
    private var chunks: [UInt32: Data] = [:]
    private var totalChunks: UInt32 = 0
    private var protoOpts: UInt8 = 0

    func addChunk(index: UInt32, data: Data, total: UInt32, opts: UInt8) {
        if totalChunks == 0 {
            totalChunks = total
            protoOpts = opts
        }
        chunks[index] = data
    }

    func isComplete() -> Bool {
        return chunks.count == Int(totalChunks) && totalChunks > 0
    }

    func reassemble() throws -> (data: Data, protoOpts: UInt8) {
        var result = Data()
        for i in 0..<totalChunks {
            guard let chunk = chunks[i] else {
                throw NSError(domain: "Missing chunk \(i)", code: 1)
            }
            result.append(chunk)
        }
        return (result, protoOpts)
    }
}

// Main receiver
Task {
    do {
        print("Listening on port \(TestConfig.testPort)...")

        let buffer = MessageBuffer()
        var receivedCount = 0
        let maxChunks = 100

        // Receive chunks
        while receivedCount < maxChunks {
            let (packet, _, _) = try UDPHelper.receive(port: TestConfig.testPort, timeout: 5.0)

            // Verify packet structure
            guard packet.count >= 22 else {
                continue
            }

            // Verify HMAC
            let receivedHMAC = packet.prefix(16)
            let message = packet.suffix(from: 16)

            let hmacKey = SymmetricKey(data: TestConfig.testKey)
            var expectedHMAC = Data(HMAC<SHA256>.authenticationCode(for: message, using: hmacKey))
            expectedHMAC = expectedHMAC.prefix(16)

            guard receivedHMAC == expectedHMAC else {
                print("ERROR: Invalid HMAC")
                continue
            }

            // Extract payload (skip GUID)
            let payload = message.suffix(from: 6)

            // Verify protocol ID
            guard payload.count > 0, payload[0] == 0x01 else {
                print("ERROR: Expected protocol ID 0x01")
                continue
            }

            // Parse header
            guard payload.count >= 16 else {
                print("ERROR: Payload too small for header")
                continue
            }

            let protoOpts = payload[1]
            let chunkIndex = payload.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt32.self) }.bigEndian
            let totalChunks = payload.withUnsafeBytes { $0.load(fromByteOffset: 12, as: UInt32.self) }.bigEndian

            // Extract data
            let data = payload.suffix(from: 16)

            // Buffer chunk
            await buffer.addChunk(index: chunkIndex, data: data, total: totalChunks, opts: protoOpts)
            receivedCount += 1

            // Check if complete
            if await buffer.isComplete() {
                // Reassemble
                let (reassembled, opts) = try await buffer.reassemble()

                // Decrypt if needed
                var processed = reassembled
                if opts & 0x02 != 0 {
                    let symmetricKey = try Data.symmetricKey(from: TestConfig.testEncryptionKey)
                    processed = try processed.aesGCMDecrypt(key: symmetricKey)
                }

                // Decompress if needed
                if opts & 0x01 != 0 {
                    processed = try processed.zlibDecompress()
                }

                print("RECEIVED: \(processed.count) bytes (protoOpts: 0x\(String(format: "%02X", opts)))")
                exit(0)
            }
        }

        print("ERROR: Timeout waiting for complete message")
        exit(1)

    } catch {
        print("ERROR: \(error)")
        exit(1)
    }
}

// Keep alive
RunLoop.main.run()
