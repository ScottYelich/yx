import Foundation
import Compression

extension Data {

    /// Compress data using ZLIB (RFC 1950)
    /// - Returns: Compressed data
    /// - Throws: CompressionError if compression fails
    public func zlibCompress() throws -> Data {
        return try (self as NSData).compressed(using: .zlib) as Data
    }

    /// Decompress data using ZLIB (RFC 1950)
    /// - Returns: Decompressed data
    /// - Throws: CompressionError if decompression fails
    public func zlibDecompress() throws -> Data {
        return try (self as NSData).decompressed(using: .zlib) as Data
    }
}

extension NSData {
    /// Compress NSData using specified algorithm
    func compressed(using algorithm: Algorithm) throws -> Data {
        guard !self.isEmpty else {
            return Data()
        }

        let streamPtr = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer {
            streamPtr.deallocate()
        }

        var stream = streamPtr.pointee
        var status: compression_status

        status = compression_stream_init(&stream, COMPRESSION_STREAM_ENCODE, algorithm.lowLevelType)
        guard status != COMPRESSION_STATUS_ERROR else {
            throw CompressionError.initializationFailed
        }
        defer {
            compression_stream_destroy(&stream)
        }

        let dstBufferSize = 4096
        let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: dstBufferSize)
        defer {
            dstBuffer.deallocate()
        }

        stream.src_ptr = self.bytes.assumingMemoryBound(to: UInt8.self)
        stream.src_size = self.length
        stream.dst_ptr = dstBuffer
        stream.dst_size = dstBufferSize

        var compressedData = Data()

        repeat {
            status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))

            if status == COMPRESSION_STATUS_ERROR {
                throw CompressionError.compressionFailed
            }

            if stream.dst_size == 0 || status == COMPRESSION_STATUS_END {
                let bytesWritten = dstBufferSize - stream.dst_size
                compressedData.append(dstBuffer, count: bytesWritten)

                stream.dst_ptr = dstBuffer
                stream.dst_size = dstBufferSize
            }
        } while status == COMPRESSION_STATUS_OK

        return compressedData
    }

    /// Decompress NSData using specified algorithm
    func decompressed(using algorithm: Algorithm) throws -> Data {
        guard !self.isEmpty else {
            return Data()
        }

        let streamPtr = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer {
            streamPtr.deallocate()
        }

        var stream = streamPtr.pointee
        var status: compression_status

        status = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, algorithm.lowLevelType)
        guard status != COMPRESSION_STATUS_ERROR else {
            throw CompressionError.initializationFailed
        }
        defer {
            compression_stream_destroy(&stream)
        }

        let dstBufferSize = 4096
        let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: dstBufferSize)
        defer {
            dstBuffer.deallocate()
        }

        stream.src_ptr = self.bytes.assumingMemoryBound(to: UInt8.self)
        stream.src_size = self.length
        stream.dst_ptr = dstBuffer
        stream.dst_size = dstBufferSize

        var decompressedData = Data()

        repeat {
            status = compression_stream_process(&stream, 0)

            if status == COMPRESSION_STATUS_ERROR {
                throw CompressionError.decompressionFailed
            }

            if stream.dst_size == 0 || status == COMPRESSION_STATUS_END {
                let bytesWritten = dstBufferSize - stream.dst_size
                decompressedData.append(dstBuffer, count: bytesWritten)

                stream.dst_ptr = dstBuffer
                stream.dst_size = dstBufferSize
            }
        } while status == COMPRESSION_STATUS_OK

        return decompressedData
    }

    enum Algorithm {
        case zlib

        var lowLevelType: compression_algorithm {
            switch self {
            case .zlib:
                return COMPRESSION_ZLIB
            }
        }
    }
}

enum CompressionError: Error, CustomStringConvertible {
    case initializationFailed
    case compressionFailed
    case decompressionFailed

    var description: String {
        switch self {
        case .initializationFailed:
            return "Failed to initialize compression stream"
        case .compressionFailed:
            return "Compression failed"
        case .decompressionFailed:
            return "Decompression failed"
        }
    }
}
