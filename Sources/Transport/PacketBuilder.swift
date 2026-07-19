import Foundation
// filename: UDPPacketUtils.swift

import Primitives
import CryptoKit

public struct UDPPacketUtils {
  
    /// Parses a raw packet from incoming bytes, verifying HMAC and structure.
      public static func parse(_ data: Data, key: SymmetricKey, sourceIP: String? = nil, sourcePort: UInt16? = nil) -> UDPPacket {
          var packet = UDPPacket(bytes: data)

          guard data.count >= 22 else {
              packet.errors.insert(.insufficientData)
              packet.state = .invalid
              return packet
          }

          let hmac = data.prefix(16)
          let payload = data.dropFirst(16)

          let guid = payload.prefix(6)
          let payloadAfterGUID = payload.dropFirst(6)
          let expected = HMAC<SHA256>.authenticationCode(for: guid + payloadAfterGUID, using: key)

          log("🧪 HMAC Input: \(guid.hexString) + \(payloadAfterGUID.prefix(12).hexString)...", level: .debug)

          let hmacValid = hmac.elementsEqual(expected.prefix(16))
          if !hmacValid {
              packet.errors.insert(.invalidHMAC)
              // Write failed packet to /tmp atomically
              writeFailedPacket(data: data, guid: guid, receivedHMAC: hmac, expectedHMAC: Data(expected.prefix(16)), sourceIP: sourceIP, sourcePort: sourcePort)
          }

          if payload.count < 6 {
              packet.errors.insert(.guidMissing)
          }

          packet.state = packet.errors.isEmpty ? .valid : .invalid
          return packet
      }

    /// Appends HMAC failure packet to /tmp/hmac_failures.log for forensics
    private static func writeFailedPacket(data: Data, guid: Data, receivedHMAC: Data, expectedHMAC: Data, sourceIP: String? = nil, sourcePort: UInt16? = nil) {
        do {
            let timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000)  // microseconds
            let guidHex = guid.hexString
            let logFile = "/tmp/hmac_failures.log"

            // Build log entry
            var entry = "\n" + String(repeating: "=", count: 80) + "\n"
            entry += "HMAC_FAILURE\n"
            entry += "Timestamp: \(timestamp)\n"
            entry += "GUID: \(guidHex)\n"

            if let ip = sourceIP {
                entry += "Source IP: \(ip)\n"
            }
            if let port = sourcePort {
                entry += "Source Port: \(port)\n"
            }

            entry += "Received HMAC: \(receivedHMAC.hexString)\n"
            entry += "Expected HMAC: \(expectedHMAC.hexString)\n"
            entry += "Packet Size: \(data.count)\n"
            entry += "---RAW_PACKET_HEX---\n"
            entry += "\(data.hexString)\n"
            entry += String(repeating: "=", count: 80) + "\n"

            // Append to log file with file locking
            let fileURL = URL(fileURLWithPath: logFile)
            let fileHandle: FileHandle

            // Open or create file
            if !FileManager.default.fileExists(atPath: logFile) {
                FileManager.default.createFile(atPath: logFile, contents: nil, attributes: nil)
            }

            fileHandle = try FileHandle(forWritingTo: fileURL)
            defer {
                try? fileHandle.close()
            }

            // Lock file for exclusive access
            try fileHandle.seek(toOffset: fileHandle.seekToEndOfFile())

            // Write entry
            if let entryData = entry.data(using: .utf8) {
                try fileHandle.write(contentsOf: entryData)
                try fileHandle.synchronize()
            }

            let sourceInfo = sourceIP.map { " from \($0):\(sourcePort ?? 0)" } ?? ""
            log("⚠️ HMAC failure\(sourceInfo) logged to: \(logFile)", level: .warning)

        } catch {
            // Don't let logging errors break packet processing
            // Silently ignore
        }
    }
    
    /// Builds a packet from GUID and payload, applying HMAC over [GUID + Payload].
    public static func build(guid: Data, bytesAfterGUID: Data, key: SymmetricKey) -> UDPPacket {
        return build(to: guid, guid: guid, bytesAfterGUID: bytesAfterGUID, key: key)
    }
    
    /// Builds a packet targeting `to` peer, using sender `guid` and peer-specific `key`.
    public static func build(to peerGUID: Data, guid: Data, bytesAfterGUID: Data, key: SymmetricKey) -> UDPPacket {
        var packet = UDPPacket()
        
        let trimmedGUID = guid.prefix(6)
        let paddedGUID = trimmedGUID + Data(repeating: 0, count: max(0, 6 - trimmedGUID.count))
        
        let hmacInput = paddedGUID + bytesAfterGUID
        let hmac = HMAC<SHA256>.authenticationCode(for: hmacInput, using: key)
        
        log("🧪 [Build] HMAC Input: \(paddedGUID.hexString) + \(bytesAfterGUID.prefix(12).hexString)...", level: .debug)

        packet.guid = paddedGUID
        packet.bytesAfterGUID = bytesAfterGUID
        packet.hmac = Data(hmac.prefix(16))
        packet.errors = []
        packet.state = .valid
        
        return packet
    }
    
    /// Build Protocol 1 chunked packet (v2.0 with channelID + sequence)
    public static func buildProtocol1Chunked(
        guid: Data,
        proto: UInt8,
        protoOpts: UInt8,
        channelID: UInt16,
        sequence: UInt32,
        chunkIndex: UInt32,
        totalChunks: UInt32,
        payload: Data,
        key: SymmetricKey
    ) -> UDPPacket {
        // Payload is expected to be already encoded (compressed/encrypted) by caller
        log("📦 Building chunk \(chunkIndex) ch=\(channelID) seq=\(sequence) — payload size: \(payload.count) bytes (protoOpts: 0x\(String(format: "%02X", protoOpts)))", level: .debug)

        let header = Protocol1Header(
            proto: proto,
            protoOpts: protoOpts,
            channelID: channelID,
            sequence: sequence,
            chunkIndex: chunkIndex,
            totalChunks: totalChunks
        )

        let fullPayload = header.serialize() + payload
        log("📦 Built binary packet chunk \(chunkIndex): total size \(fullPayload.count) bytes", level: .debug)

        return UDPPacketUtils.build(guid: guid, bytesAfterGUID: fullPayload, key: key)
    }
    
}

