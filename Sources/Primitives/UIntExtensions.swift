import Foundation

public extension UInt16 {
    var bigEndianBytes: Data {
        withUnsafeBytes(of: self.bigEndian) { Data($0) }
    }
}

public extension UInt32 {
    var bigEndianBytes: Data {
        withUnsafeBytes(of: self.bigEndian) { Data($0) }
    }
}
