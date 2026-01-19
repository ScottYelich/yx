import Foundation

public struct GUIDFactory {
    public static func generate() -> Data {
        var bytes = [UInt8](repeating: 0, count: 6)
        _ = SecRandomCopyBytes(kSecRandomDefault, 6, &bytes)
        return Data(bytes)
    }

    public static func pad(guid: Data) -> Data {
        if guid.count == 6 {
            return guid
        } else if guid.count < 6 {
            return guid + Data(repeating: 0, count: 6 - guid.count)
        } else {
            return guid.prefix(6)
        }
    }

    public static func fromHex(_ hexString: String) -> Data {
        var data = Data()
        var hex = hexString
        while hex.count >= 2 {
            let index = hex.index(hex.startIndex, offsetBy: 2)
            let byteString = String(hex[..<index])
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            }
            hex = String(hex[index...])
        }
        return pad(guid: data)
    }

    public static func toHex(_ guid: Data) -> String {
        return guid.map { String(format: "%02x", $0) }.joined()
    }
}
