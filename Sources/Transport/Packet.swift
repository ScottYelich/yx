import Foundation
// filename: UDPPacket.swift

import Primitives

public enum PacketState: Sendable {
    case unknown
    case valid
    case invalid
}

public enum PacketValidationError: Hashable, Sendable {
    case invalidHMAC
    case insufficientData
    case guidMissing
}

public struct UDPPacket: Sendable {

    private static let hmacLength = 16
    private static let guidLength = 6
    private static let minimumLength = hmacLength + guidLength

    public var bytes: Data
    public var errors: Set<PacketValidationError>
    public var state: PacketState

    public init() {
        self.init(bytes: Data(repeating: 0, count: Self.minimumLength))
    }

    init(bytes: Data) {
        self.bytes = bytes
        self.errors = []
        self.state = .unknown
    }

    mutating func setBytes(_ newBytes: Data) {
        self.bytes = newBytes
        self.errors = []
        self.state = .unknown
    }

    var hmac: Data? {
        get {
            guard bytes.count >= Self.hmacLength else { return nil }
            return bytes.prefix(Self.hmacLength)
        }
        set {
            ensureSize(minimum: Self.minimumLength)
            bytes.replaceSubrange(0..<Self.hmacLength, with: newValue?.prefix(Self.hmacLength) ?? Data(repeating: 0, count: Self.hmacLength))
            resetState()
        }
    }

    var bytesAfterHMAC: Data? {
        guard bytes.count > Self.hmacLength else { return nil }
        return Data(bytes.dropFirst(Self.hmacLength))
    }

    public var guid: Data? {
        get {
            guard bytes.count >= Self.minimumLength else { return nil }
            let start = Self.hmacLength
            let end = start + Self.guidLength
            return bytes[start..<end]
        }
        set {
            ensureSize(minimum: Self.minimumLength)
            let start = Self.hmacLength
            let end = start + Self.guidLength
            bytes.replaceSubrange(start..<end, with: newValue?.prefix(Self.guidLength) ?? Data(repeating: 0, count: Self.guidLength))
            resetState()
        }
    }

    public var bytesAfterGUID: Data {
        get {
            guard bytes.count > Self.minimumLength else { return Data() }
            return Data(bytes.dropFirst(Self.minimumLength))
        }
        set {
            ensureSize(minimum: Self.minimumLength)
            bytes.replaceSubrange(Self.minimumLength..<bytes.count, with: newValue)
            resetState()
        }
    }

    private mutating func resetState() {
        self.errors = []
        self.state = .unknown
    }

    private mutating func ensureSize(minimum: Int) {
        if bytes.count < minimum {
            bytes.append(contentsOf: [UInt8](repeating: 0, count: minimum - bytes.count))
        }
    }
    
}
