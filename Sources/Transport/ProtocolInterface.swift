import Foundation
// filename: ProtocolInterface.swift

import Primitives
import CryptoKit

/// Base protocol for all packet protocol handlers.
///
/// Implementers must process incoming packets with a specific protocol ID.
/// Use constructor injection to provide dependencies (router, networking, etc.).
public protocol ProtocolInterface: Sendable {
    /// Returns the protocol byte used for routing (e.g. 0x00 for text, 0x01 for binary)
    func proto() async -> UInt8

    /// Called by router to process a matching incoming packet.
    func ingest(_ packet: UDPPacket, key: SymmetricKey) async
}

