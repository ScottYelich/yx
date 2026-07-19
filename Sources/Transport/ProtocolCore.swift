import Foundation
// filename: ProtocolActorCore.swift

import Primitives
import CryptoKit

public final class ProtocolActorCore: @unchecked Sendable {

    public let proto: UInt8
    private var handler: ((Data) async -> Void)?

    public init(proto: UInt8) {
        self.proto = proto
    }

    public func setReceiveHandler(_ handler: @escaping @Sendable (Data) async -> Void) {
        self.handler = handler
    }

    public func handlePayload(_ data: Data) async {
        await handler?(data)
    }
}


