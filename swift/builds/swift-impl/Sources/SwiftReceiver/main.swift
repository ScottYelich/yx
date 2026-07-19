import Foundation
import YXProtocol

// SwiftReceiver - YX Protocol interop test receiver
// Implements: protocol/specs/testing/interoperability-requirements.md
//
// Usage: SwiftReceiver <mode> [timeout_seconds]
// Modes: proto0, proto1
// Receives one message (or reassembles one binary transmission) then exits.
// Exit code: 0 = success, 1 = failure

func runReceiver() throws {
    let args = CommandLine.arguments
    guard args.count >= 2 else {
        print("Usage: SwiftReceiver <mode> [timeout_seconds]")
        exit(1)
    }

    let mode = args[1]
    let timeoutSecs = args.count > 2 ? Double(args[2]) ?? 5.0 : 5.0
    let key = TestConfig.testKey
    let port = TestConfig.testPort

    let socket = UDPSocket(port: port)
    try socket.bind()
    socket.setTimeout(timeoutSecs)
    defer { socket.close() }

    switch mode {
    case "proto0":
        guard let (guid, payload, _) = try socket.receivePacket(key: key) else {
            fputs("FAILED: timeout\n", stderr)
            exit(1)
        }
        guard payload.count >= 1, payload[0] == 0x00 else {
            fputs("FAILED: not a proto0 packet (got \(payload.first.map { "0x\(String($0, radix: 16))" } ?? "empty"))\n", stderr)
            exit(1)
        }
        let jsonData = payload.dropFirst()
        guard let parsed = try? JSONSerialization.jsonObject(with: jsonData) else {
            fputs("FAILED: invalid JSON\n", stderr)
            exit(1)
        }
        let guidHex = guid.map { String(format: "%02X", $0) }.joined()
        print("RECEIVED proto0 guid=\(guidHex): \(parsed)")
        exit(0)

    case "proto1":
        // Reassemble binary chunks
        var chunks: [UInt32: Data] = [:]
        var totalChunks: UInt32 = 0
        var protoOpts: UInt8 = 0
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeoutSecs {
            guard let (_, payload, _) = try socket.receivePacket(key: key) else {
                break
            }
            guard payload.count >= 16, payload[0] == 0x01 else { continue }

            protoOpts = payload[1]
            let chunkIndex = payload[8..<12].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let total = payload[12..<16].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let chunkData = payload.dropFirst(16)

            chunks[chunkIndex] = Data(chunkData)
            totalChunks = total

            if UInt32(chunks.count) == totalChunks { break }
        }

        guard UInt32(chunks.count) == totalChunks, totalChunks > 0 else {
            fputs("FAILED: incomplete reassembly (\(chunks.count)/\(totalChunks))\n", stderr)
            exit(1)
        }

        // Reassemble in order
        var assembled = Data()
        for i in 0..<totalChunks {
            guard let chunk = chunks[i] else {
                fputs("FAILED: missing chunk \(i)\n", stderr)
                exit(1)
            }
            assembled.append(chunk)
        }

        // Decrypt if needed
        if protoOpts & 0x02 != 0 {
            guard let symKey = try? Data.symmetricKey(from: key) else {
                fputs("FAILED: key error\n", stderr)
                exit(1)
            }
            guard let decrypted = try? assembled.aesGCMDecrypt(key: symKey) else {
                fputs("FAILED: decryption error\n", stderr)
                exit(1)
            }
            assembled = decrypted
        }

        // Decompress if needed
        if protoOpts & 0x01 != 0 {
            guard let decompressed = try? assembled.zlibDecompress() else {
                fputs("FAILED: decompression error\n", stderr)
                exit(1)
            }
            assembled = decompressed
        }

        print("RECEIVED proto1: \(assembled.count) bytes")
        exit(0)

    default:
        print("Unknown mode: \(mode)")
        exit(1)
    }
}

do {
    try runReceiver()
} catch {
    fputs("FAILED: \(error)\n", stderr)
    exit(1)
}
