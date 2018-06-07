///
///  DataCompression
///
///  libcompression wrapper as an extension for the `Data` type
///  (ZLIB, LZFSE, LZMA, LZ4, deflate, RFC-1950, RFC-1951)
///
///  Created by Markus Wanke, 2016/12/05
///


///
///                Apache License, Version 2.0
///
///  Copyright 2016, Markus Wanke
///
///  Licensed under the Apache License, Version 2.0 (the "License");
///  you may not use this file except in compliance with the License.
///  You may obtain a copy of the License at
///
///  http://www.apache.org/licenses/LICENSE-2.0
///
///  Unless required by applicable law or agreed to in writing, software
///  distributed under the License is distributed on an "AS IS" BASIS,
///  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
///  See the License for the specific language governing permissions and
///  limitations under the License.
///


import Foundation
import Compression

public extension Data
{
    /// Compresses the data.
    /// - parameter withAlgorithm: Compression algorithm to use. See the `CompressionAlgorithm` type
    /// - returns: compressed data
    public func compress(withAlgorithm algo: CompressionAlgorithm) -> Data?
    {
        return self.withUnsafeBytes { (sourcePtr: UnsafePointer<UInt8>) -> Data? in
            let config = (operation: COMPRESSION_STREAM_ENCODE, algorithm: algo.lowLevelType)
            return perform(config, source: sourcePtr, sourceSize: count)
        }
    }

    /// Decompresses the data.
    /// - parameter withAlgorithm: Compression algorithm to use. See the `CompressionAlgorithm` type
    /// - returns: decompressed data
    public func decompress(withAlgorithm algo: CompressionAlgorithm) -> Data?
    {
        return self.withUnsafeBytes { (sourcePtr: UnsafePointer<UInt8>) -> Data? in
            let config = (operation: COMPRESSION_STREAM_DECODE, algorithm: algo.lowLevelType)
            return perform(config, source: sourcePtr, sourceSize: count)
        }
    }

    /// Please consider the [libcompression documentation](https://developer.apple.com/reference/compression/1665429-data_compression)
    /// for further details. Short info:
    /// ZLIB  : Fast with a very solid compression rate. There is a reason it is used everywhere.
    /// LZFSE : Apples proprietary compression algorithm. Claims to compress as good as ZLIB but 2 to 3 times faster.
    /// LZMA  : Horribly slow. Compression as well as decompression. Normally you will regret choosing LZMA.
    /// LZ4   : Fast, but depending on the data the compression rate can be really bad. Which is often the case.
    public enum CompressionAlgorithm
    {
        case ZLIB
        case LZFSE
        case LZMA
        case LZ4
    }

    /// Compresses the data using the zlib deflate algorithm.
    /// - returns: raw deflated data according to [RFC-1951](https://tools.ietf.org/html/rfc1951).
    /// - note: Fixed at compression level 5 (best trade off between speed and time)
    public func deflate() -> Data?
    {
        return self.withUnsafeBytes { (sourcePtr: UnsafePointer<UInt8>) -> Data? in
            let config = (operation: COMPRESSION_STREAM_ENCODE, algorithm: COMPRESSION_ZLIB)
            return perform(config, source: sourcePtr, sourceSize: count)
        }
    }

    /// Deompresses the data using the zlib deflate algorithm. Self is expected to be a raw deflate
    /// stream according to [RFC-1951](https://tools.ietf.org/html/rfc1951).
    /// - returns: uncompressed data
    public func inflate() -> Data?
    {
        return self.withUnsafeBytes { (sourcePtr: UnsafePointer<UInt8>) -> Data? in
            let config = (operation: COMPRESSION_STREAM_DECODE, algorithm: COMPRESSION_ZLIB)
            return perform(config, source: sourcePtr, sourceSize: count)
        }
    }

    /// Compresses the data using the zlib deflate algorithm.
    /// - returns: zlib deflated data according to [RFC-1950](https://tools.ietf.org/html/rfc1950)
    /// - note: Fixed at compression level 5 (best trade off between speed and time)
    public func zip() -> Data?
    {
        var res = Data(bytes: [0x78, 0x5e])

        guard let deflated = self.deflate() else { return nil }
        res.append(deflated)

        var adler = self.adler32().bigEndian
        res.append(Data(bytes: &adler, count: MemoryLayout<UInt32>.size))

        return res
    }

    /// Deompresses the data using the zlib deflate algorithm. Self is expected to be a zlib deflate
    /// stream according to [RFC-1950](https://tools.ietf.org/html/rfc1950).
    /// - returns: uncompressed data
    public func unzip(skipCheckSumValidation: Bool = true) -> Data?
    {
        // 2 byte header + 4 byte adler32 checksum
        let overhead = 6
        guard count > overhead else { return nil }

        let header: UInt16 = withUnsafeBytes { (ptr: UnsafePointer<UInt16>) -> UInt16 in
            return ptr.pointee.bigEndian
        }

        // check for the deflate stream bit
        guard header >> 8 & 0b1111 == 0b1000 else { return nil }
        // check the header checksum
        guard header % 31 == 0 else { return nil }

        let cresult: Data? = withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> Data? in
            let source = ptr.advanced(by: 2)
            let config = (operation: COMPRESSION_STREAM_DECODE, algorithm: COMPRESSION_ZLIB)
            return perform(config, source: source, sourceSize: count - overhead)
        }

        guard let inflated = cresult else { return nil }

        if skipCheckSumValidation { return inflated }

        let cksum: UInt32 = withUnsafeBytes { (bytePtr: UnsafePointer<UInt8>) -> UInt32 in
            let last = bytePtr.advanced(by: count - 4)
            return last.withMemoryRebound(to: UInt32.self, capacity: 1) { (intPtr) -> UInt32 in
                return intPtr.pointee.bigEndian
            }
        }

        return cksum == inflated.adler32() ? inflated : nil
    }

    /// Rudimentary implementation of the adler32 checksum.
    /// - returns: adler32 checksum (4 byte)
    public func adler32() -> UInt32
    {
        var s1: UInt32 = 1
        var s2: UInt32 = 0
        let prime: UInt32 = 65521

        for byte in self {
            s1 += UInt32(byte)
            if s1 >= prime { s1 = s1 % prime }
            s2 += s1
            if s2 >= prime { s2 = s2 % prime }
        }

        return (s2 << 16) | s1
    }
}


fileprivate extension Data.CompressionAlgorithm
{
    var lowLevelType: compression_algorithm {
        switch self {
        case .ZLIB    : return COMPRESSION_ZLIB
        case .LZFSE   : return COMPRESSION_LZFSE
        case .LZ4     : return COMPRESSION_LZ4
        case .LZMA    : return COMPRESSION_LZMA
        }
    }
}

fileprivate typealias Config = (operation: compression_stream_operation, algorithm: compression_algorithm)


fileprivate func perform(_ config: Config, source: UnsafePointer<UInt8>, sourceSize: Int) -> Data?
{
    guard config.operation == COMPRESSION_STREAM_ENCODE || sourceSize > 0 else { return nil }

    let streamBase = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
    defer { streamBase.deallocate() }
    var stream = streamBase.pointee

    let status = compression_stream_init(&stream, config.operation, config.algorithm)
    guard status != COMPRESSION_STATUS_ERROR else { return nil }
    defer { compression_stream_destroy(&stream) }

    let bufferSize = Swift.max( Swift.min(sourceSize, 64 * 1024), 64)
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    stream.dst_ptr  = buffer
    stream.dst_size = bufferSize
    stream.src_ptr  = source
    stream.src_size = sourceSize

    var res = Data()
    let flags: Int32 = Int32(COMPRESSION_STREAM_FINALIZE.rawValue)

    while true {
        switch compression_stream_process(&stream, flags) {
        case COMPRESSION_STATUS_OK:
            guard stream.dst_size == 0 else { return nil }
            res.append(buffer, count: stream.dst_ptr - buffer)
            stream.dst_ptr = buffer
            stream.dst_size = bufferSize

        case COMPRESSION_STATUS_END:
            res.append(buffer, count: stream.dst_ptr - buffer)
            return res

        default:
            return nil
        }
    }
}
