import Foundation
//
//  ProtocolHandler.swift
//  yx
//
//  Created by Scott Yelich on 5/20/25.
//

// filename: ProtocolHandler.swift

import Primitives
import CryptoKit

/// A protocol that all protocol actors (e.g., TextProtocol, BinaryProtocol) must conform to.
/// Combines ingesting, sending, and receive-handler installation in a unified interface.
public protocol ProtocolHandler: ProtocolInterface {
    /// The protocol number (e.g., 0x00 for text, 0x01 for binary)
    func proto() async -> UInt8

    /// Called by NetworkSystem to provide networking reference after creation.
    func installSendAPI(_ send: @escaping @Sendable (_ data: Data, _ host: String, _ port: UInt16) async -> Void) async

    /// Optionally send a payload to a target host/port.
    func send(_ payload: Data, to host: String, port: UInt16) async

    /// Sets the handler that will receive reassembled payloads from incoming messages.
    func setReceiveHandler(_ handler: @escaping @Sendable (Data) async -> Void) async
}
