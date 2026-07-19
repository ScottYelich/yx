import Foundation
// filename: ProtocolRouter.swift

import Primitives
import CryptoKit

/// Actor responsible for dispatching incoming packets to protocol handlers.
public actor ProtocolRouter {
    private var registry: [UInt8: ProtocolInterface] = [:]
    private var textHandler: ProtocolInterface?

    public init() {}

    /// Registers a binary protocol handler (proto byte < 32).
    public func register(_ handler: ProtocolInterface) async {
        let protoByte = await handler.proto()
        registry[protoByte] = handler
    }

    /// Unregisters a binary protocol handler for a specific proto byte.
    public func unregister(proto: UInt8) {
        registry.removeValue(forKey: proto)
    }

    /// Sets the default handler for non-binary packets (proto byte ≥ 32).
    public func setTextHandler(_ handler: ProtocolInterface) {
        textHandler = handler
    }

    /// Dispatches the packet to the appropriate handler based on proto byte.
    public func route(_ packet: UDPPacket, key: SymmetricKey, via networking: Networking) async {
        log("🔀 ProtocolRouter.route() called", level: .info)
        log("   📦 Packet state: \(packet.state)", level: .info)
        log("   📏 bytesAfterGUID count: \(packet.bytesAfterGUID.count)", level: .info)

        guard packet.state == .valid else {
            if let guid = packet.guid, guid == networking.localGUID {
                return // Suppress invalid self-sent messages
            }
            log("❌ PacketRouter: Invalid packet state", level: .error)
            log("   ⛔ Raw length: \(packet.bytes.count)", level: .error)
            log("   ⛔ Raw prefix: \(packet.bytes.prefix(24).hexString) ...", level: .error)
            return
        }

        guard let firstByte = packet.bytesAfterGUID.first else {
            log("❌ PacketRouter: Empty payload", level: .error)
            return
        }

        log("   🔢 First byte: \(firstByte) (0x\(String(format: "%02X", firstByte)))", level: .info)

        if firstByte < 32 {
            log("   📂 Binary protocol path (< 32)", level: .info)
            log("   📋 Registry has \(registry.count) handlers", level: .info)
            for (_, handler) in registry {
                let protoByte = await handler.proto()
                log("      Checking handler with proto \(protoByte)", level: .info)
                if protoByte == firstByte {
                    log("   ✅ Found matching handler! Calling ingest()", level: .info)
                    await handler.ingest(packet, key: key)
                    return
                }
            }
            log("❌ PacketRouter: No handler registered for proto \(firstByte)", level: .error)
        } else {
            log("   📝 Text protocol path (>= 32)", level: .info)
            log("   🔍 textHandler is: \(textHandler == nil ? "NIL" : "SET")", level: .info)
            guard let handler = textHandler else {
                log("❌ PacketRouter: No text handler set", level: .error)
                return
            }
            log("   ✅ Text handler found! Calling ingest()", level: .info)
            await handler.ingest(packet, key: key)
        }
    }
}


