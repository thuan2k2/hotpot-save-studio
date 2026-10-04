import Compression
import Foundation

enum GzipCodecError: LocalizedError {
    case invalidHeader
    case invalidChecksum
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .invalidHeader: return "Dữ liệu GZIP không hợp lệ."
        case .invalidChecksum: return "Dữ liệu GZIP bị hỏng (sai checksum)."
        case .compressionFailed: return "Không thể nén hoặc giải nén dữ liệu."
        }
    }
}

/// GZIP wrapper using Apple's raw DEFLATE encoder. Data_BackUp requires GZIP,
/// not a zlib stream, hence the explicit RFC 1952 header and trailer.
enum GzipCodec {
    static func compress(_ source: Data) throws -> Data {
        let deflated = try transform(source, operation: COMPRESSION_STREAM_ENCODE)
        var result = Data([0x1f, 0x8b, 0x08, 0x00, 0, 0, 0, 0, 0, 0xff])
        result.append(deflated)
        result.appendLittleEndian(crc32(source))
        result.appendLittleEndian(UInt32(source.count & 0xffff_ffff))
        return result
    }

    static func decompress(_ source: Data) throws -> Data {
        let bytes = [UInt8](source)
        guard bytes.count >= 18, bytes[0] == 0x1f, bytes[1] == 0x8b, bytes[2] == 8 else {
            throw GzipCodecError.invalidHeader
        }
        var index = 10
        let flags = bytes[3]
        if flags & 0x04 != 0 {
            guard index + 2 <= bytes.count else { throw GzipCodecError.invalidHeader }
            let length = Int(bytes[index]) | Int(bytes[index + 1]) << 8
            index += 2 + length
        }
        for mask in [UInt8(0x08), 0x10] where flags & mask != 0 {
            while index < bytes.count && bytes[index] != 0 { index += 1 }
            index += 1
        }
        if flags & 0x02 != 0 { index += 2 }
        guard index <= bytes.count - 8 else { throw GzipCodecError.invalidHeader }

        let inflated = try transform(Data(bytes[index..<(bytes.count - 8)]), operation: COMPRESSION_STREAM_DECODE)
        let expectedCRC = source.uint32LittleEndian(at: bytes.count - 8)
        let expectedSize = source.uint32LittleEndian(at: bytes.count - 4)
        guard crc32(inflated) == expectedCRC, UInt32(inflated.count & 0xffff_ffff) == expectedSize else {
            throw GzipCodecError.invalidChecksum
        }
        return inflated
    }

    private static func transform(_ source: Data, operation: compression_stream_operation) throws -> Data {
        guard !source.isEmpty else { return Data() }
        var stream = compression_stream(
            dst_ptr: nil,
            dst_size: 0,
            src_ptr: nil,
            src_size: 0,
            state: nil
        )
        guard compression_stream_init(&stream, operation, COMPRESSION_ZLIB) != COMPRESSION_STATUS_ERROR else {
            throw GzipCodecError.compressionFailed
        }
        defer { compression_stream_destroy(&stream) }

        return try source.withUnsafeBytes { rawBuffer in
            guard let input = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                throw GzipCodecError.compressionFailed
            }
            stream.src_ptr = input
            stream.src_size = source.count
            var output = Data()
            var status: compression_status = COMPRESSION_STATUS_OK
            repeat {
                let bufferSize = 32_768
                var buffer = [UInt8](repeating: 0, count: bufferSize)
                try buffer.withUnsafeMutableBytes { rawOutput in
                    guard let destination = rawOutput.bindMemory(to: UInt8.self).baseAddress else {
                        throw GzipCodecError.compressionFailed
                    }
                    stream.dst_ptr = destination
                    stream.dst_size = bufferSize
                    status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE))
                    output.append(destination, count: bufferSize - stream.dst_size)
                }
            } while status == COMPRESSION_STATUS_OK
            guard status == COMPRESSION_STATUS_END else { throw GzipCodecError.compressionFailed }
            return output
        }
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffff_ffff
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = crc & 1 == 1 ? (crc >> 1) ^ 0xedb8_8320 : crc >> 1 }
        }
        return crc ^ 0xffff_ffff
    }
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt32) {
        var littleEndian = value.littleEndian
        append(Data(bytes: &littleEndian, count: MemoryLayout<UInt32>.size))
    }

    func uint32LittleEndian(at offset: Int) -> UInt32 {
        withUnsafeBytes { raw in raw.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian }
    }
}
