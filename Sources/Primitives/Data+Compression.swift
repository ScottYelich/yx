import Foundation
// filename: Data+Compression.swift

import Compression

public extension Data {
    /// Compresses the Data using the specified compression algorithm
    func compressed(using algorithm: compression_algorithm) -> Data? {
        guard !self.isEmpty else { return Data() }

        let bufferSize = 64 * 1024
        var encoded = Data()

        return self.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Data? in
            guard let srcBase = srcPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { dstBuffer.deallocate() }

            var stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1).pointee
            let statusInit = compression_stream_init(&stream, COMPRESSION_STREAM_ENCODE, algorithm)
            guard statusInit != COMPRESSION_STATUS_ERROR else {
                return nil
            }
            defer { compression_stream_destroy(&stream) }

            stream.src_ptr = srcBase
            stream.src_size = self.count
            stream.dst_ptr = dstBuffer
            stream.dst_size = bufferSize

            while true {
                let status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))

                switch status {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    let produced = bufferSize - stream.dst_size
                    encoded.append(dstBuffer, count: produced)

                    if status == COMPRESSION_STATUS_END {
                        return encoded
                    }

                    stream.dst_ptr = dstBuffer
                    stream.dst_size = bufferSize

                default:
                    return nil
                }
            }
        }
    }

    /// Decompresses the Data using the specified compression algorithm
    func decompressed(using algorithm: compression_algorithm) -> Data? {
        guard !self.isEmpty else { return Data() }

        let bufferSize = 64 * 1024
        var decoded = Data()

        return self.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Data? in
            guard let srcBase = srcPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { dstBuffer.deallocate() }

            var stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1).pointee
            let statusInit = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, algorithm)
            guard statusInit != COMPRESSION_STATUS_ERROR else {
                return nil
            }
            defer { compression_stream_destroy(&stream) }

            stream.src_ptr = srcBase
            stream.src_size = self.count
            stream.dst_ptr = dstBuffer
            stream.dst_size = bufferSize

            while true {
                let status = compression_stream_process(&stream, 0)

                switch status {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    let produced = bufferSize - stream.dst_size
                    decoded.append(dstBuffer, count: produced)

                    if status == COMPRESSION_STATUS_END {
                        return decoded
                    }

                    stream.dst_ptr = dstBuffer
                    stream.dst_size = bufferSize

                default:
                    return nil
                }
            }
        }
    }
}
