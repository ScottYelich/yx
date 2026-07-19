import Foundation


public extension Data {
    /// Returns a UTF-8 string representation of the Data, if valid
    var utf8String: String? {
        String(data: self, encoding: .utf8)
    }
}
