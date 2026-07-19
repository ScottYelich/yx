import Foundation
// filename: Data+Hex.swift


public extension Data {
    /// Converts the Data into a hex string (e.g. "0A1B2C")
    var hexString: String {
        map { String(format: "%02X", $0) }.joined()
    }

    /// Initializes Data from a hex string (must be even-length and valid hex)
    init?(hex: String) {
        let len = hex.count / 2
        var data = Data(capacity: len)
        var index = hex.startIndex

        for _ in 0..<len {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard nextIndex <= hex.endIndex,
                  let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }

        self = data
    }

    /// Returns a formatted hex + ASCII view of the data (like hexdump -C)
    func hexdump(bytesPerLine: Int = 16) -> String {
        var output = ""
        var offset = 0

        while offset < self.count {
            let chunkEnd = Swift.min(offset + bytesPerLine, self.count)
            let chunk = self[offset..<chunkEnd]

            let hexBytes = chunk.map { String(format: "%02X", $0) }.joined(separator: " ")
            let ascii = chunk.map { byte -> String in
                let c = Character(UnicodeScalar(byte))
                return c.isASCII && c.isPrintable ? String(c) : "."
            }.joined()

            let padding = String(repeating: " ", count: (bytesPerLine - chunk.count) * 3)
            output += String(format: "%04X: %@%@  %@\n", offset, hexBytes, padding, ascii)

            offset += bytesPerLine
        }

        return output
    }
}

private extension Character {
    var isPrintable: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.isASCII && (scalar.value >= 0x20 && scalar.value <= 0x7E)
    }
}
