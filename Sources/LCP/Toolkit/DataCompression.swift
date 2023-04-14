///
///  DataCompression
///
///  A libcompression wrapper as an extension for the `Data` type
///  (GZIP, ZLIB, LZFSE, LZMA, LZ4, deflate, RFC-1950, RFC-1951, RFC-1952)
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

import Compression
import Foundation

public extension Data {
    /// Compresses the data.
    /// - parameter withAlgorithm: Compression algorithm to use. See the `CompressionAlgorithm` type
    /// - returns: compressed data
    func compress(withAlgorithm algo: CompressionAlgorithm) -> Data? {
        withUnsafeBytes { (sourcePtr: UnsafePointer<UInt8>) -> Data? in
            let config = (operation: COMPRESSION_STREAM_ENCODE, algorithm: algo.lowLevelType)
            return perform(config, source: sourcePtr, sourceSize: count)
        }
    }

    /// Decompresses the data.
    /// - parameter withAlgorithm: Compression algorithm to use. See the `CompressionAlgorithm` type
    /// - returns: decompressed data
    func decompress(withAlgorithm algo: CompressionAlgorithm) -> Data? {
        withUnsafeBytes { (sourcePtr: UnsafePointer<UInt8>) -> Data? in
            let config = (operation: COMPRESSION_STREAM_DECODE, algorithm: algo.lowLevelType)
            return perform(config, source: sourcePtr, sourceSize: count)
        }
    }

    /// Please consider the [libcompression documentation](https://developer.apple.com/reference/compression/1665429-data_compression)
    /// for further details. Short info:
    /// zlib  : Aka deflate. Fast with a good compression rate. Proved itself over time and is supported everywhere.
    /// lzfse : Apples custom Lempel-Ziv style compression algorithm. Claims to compress as good as zlib but 2 to 3 times faster.
    /// lzma  : Horribly slow. Compression as well as decompression. Compresses better than zlib though.
    /// lz4   : Fast, but compression rate is very bad. Apples lz4 implementation often to not compress at all.
    enum CompressionAlgorithm {
        case zlib
        case lzfse
        case lzma
        case lz4
    }

    /// Compresses the data using the zlib deflate algorithm.
    /// - returns: raw deflated data according to [RFC-1951](https://tools.ietf.org/html/rfc1951).
    /// - note: Fixed at compression level 5 (best trade off between speed and time)
    func deflate() -> Data? {
        withUnsafeBytes { (sourcePtr: UnsafePointer<UInt8>) -> Data? in
            let config = (operation: COMPRESSION_STREAM_ENCODE, algorithm: COMPRESSION_ZLIB)
            return perform(config, source: sourcePtr, sourceSize: count)
        }
    }

    /// Decompresses the data using the zlib deflate algorithm. Self is expected to be a raw deflate
    /// stream according to [RFC-1951](https://tools.ietf.org/html/rfc1951).
    /// - returns: uncompressed data
    func inflate() -> Data? {
        withUnsafeBytes { (sourcePtr: UnsafePointer<UInt8>) -> Data? in
            let config = (operation: COMPRESSION_STREAM_DECODE, algorithm: COMPRESSION_ZLIB)
            return perform(config, source: sourcePtr, sourceSize: count)
        }
    }

    /// Compresses the data using the deflate algorithm and makes it comply to the zlib format.
    /// - returns: deflated data in zlib format [RFC-1950](https://tools.ietf.org/html/rfc1950)
    /// - note: Fixed at compression level 5 (best trade off between speed and time)
    func zip() -> Data? {
        let header = Data([0x78, 0x5E])

        let deflated = withUnsafeBytes { (sourcePtr: UnsafePointer<UInt8>) -> Data? in
            let config = (operation: COMPRESSION_STREAM_ENCODE, algorithm: COMPRESSION_ZLIB)
            return perform(config, source: sourcePtr, sourceSize: count, preload: header)
        }

        guard var result = deflated else { return nil }

        var adler = adler32().checksum.bigEndian
        result.append(Data(bytes: &adler, count: MemoryLayout<UInt32>.size))

        return result
    }

    /// Decompresses the data using the zlib deflate algorithm. Self is expected to be a zlib deflate
    /// stream according to [RFC-1950](https://tools.ietf.org/html/rfc1950).
    /// - returns: uncompressed data
    func unzip(skipCheckSumValidation: Bool = true) -> Data? {
        // 2 byte header + 4 byte adler32 checksum
        let overhead = 6
        guard count > overhead else { return nil }

        let header: UInt16 = withUnsafeBytes { (ptr: UnsafePointer<UInt16>) -> UInt16 in
            ptr.pointee.bigEndian
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
            return last.withMemoryRebound(to: UInt32.self, capacity: 1) { intPtr -> UInt32 in
                intPtr.pointee.bigEndian
            }
        }

        return cksum == inflated.adler32().checksum ? inflated : nil
    }

    /// Compresses the data using the deflate algorithm and makes it comply to the gzip stream format.
    /// - returns: deflated data in gzip format [RFC-1952](https://tools.ietf.org/html/rfc1952)
    /// - note: Fixed at compression level 5 (best trade off between speed and time)
    func gzip() -> Data? {
        var header = Data([0x1F, 0x8B, 0x08, 0x00]) // magic, magic, deflate, noflags

        var unixtime = UInt32(Date().timeIntervalSince1970).littleEndian
        header.append(Data(bytes: &unixtime, count: MemoryLayout<UInt32>.size))

        header.append(contentsOf: [0x00, 0x03]) // normal compression level, unix file type

        let deflated = withUnsafeBytes { (sourcePtr: UnsafePointer<UInt8>) -> Data? in
            let config = (operation: COMPRESSION_STREAM_ENCODE, algorithm: COMPRESSION_ZLIB)
            return perform(config, source: sourcePtr, sourceSize: count, preload: header)
        }

        guard var result = deflated else { return nil }

        // append checksum
        var crc32: UInt32 = crc32().checksum.littleEndian
        result.append(Data(bytes: &crc32, count: MemoryLayout<UInt32>.size))

        // append size of original data
        var isize = UInt32(truncatingIfNeeded: count).littleEndian
        result.append(Data(bytes: &isize, count: MemoryLayout<UInt32>.size))

        return result
    }

    /// Decompresses the data using the gzip deflate algorithm. Self is expected to be a gzip deflate
    /// stream according to [RFC-1952](https://tools.ietf.org/html/rfc1952).
    /// - returns: uncompressed data
    func gunzip() -> Data? {
        // 10 byte header + data +  8 byte footer. See https://tools.ietf.org/html/rfc1952#section-2
        let overhead = 10 + 8
        guard count >= overhead else { return nil }

        typealias GZipHeader = (id1: UInt8, id2: UInt8, cm: UInt8, flg: UInt8, xfl: UInt8, os: UInt8)
        let hdr: GZipHeader = withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> GZipHeader in
            // +---+---+---+---+---+---+---+---+---+---+
            // |ID1|ID2|CM |FLG|     MTIME     |XFL|OS |
            // +---+---+---+---+---+---+---+---+---+---+
            (id1: ptr[0], id2: ptr[1], cm: ptr[2], flg: ptr[3], xfl: ptr[8], os: ptr[9])
        }

        typealias GZipFooter = (crc32: UInt32, isize: UInt32)
        let ftr: GZipFooter = withUnsafeBytes { (bptr: UnsafePointer<UInt8>) -> GZipFooter in
            // +---+---+---+---+---+---+---+---+
            // |     CRC32     |     ISIZE     |
            // +---+---+---+---+---+---+---+---+
            bptr.advanced(by: count - 8).withMemoryRebound(to: UInt32.self, capacity: 2) { ptr in
                (ptr[0].littleEndian, ptr[1].littleEndian)
            }
        }

        // Wrong gzip magic or unsupported compression method
        guard hdr.id1 == 0x1F, hdr.id2 == 0x8B, hdr.cm == 0x08 else { return nil }

        let has_crc16: Bool = hdr.flg & 0b00010 != 0
        let has_extra: Bool = hdr.flg & 0b00100 != 0
        let has_fname: Bool = hdr.flg & 0b01000 != 0
        let has_cmmnt: Bool = hdr.flg & 0b10000 != 0

        let cresult: Data? = withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> Data? in
            var pos = 10; let limit = count - 8

            if has_extra {
                pos += ptr.advanced(by: pos).withMemoryRebound(to: UInt16.self, capacity: 1) {
                    Int($0.pointee.littleEndian) + 2 // +2 for xlen
                }
            }
            if has_fname {
                while pos < limit, ptr[pos] != 0x0 { pos += 1 }
                pos += 1 // skip null byte as well
            }
            if has_cmmnt {
                while pos < limit, ptr[pos] != 0x0 { pos += 1 }
                pos += 1 // skip null byte as well
            }
            if has_crc16 {
                pos += 2 // ignoring header crc16
            }

            guard pos < limit else { return nil }
            let config = (operation: COMPRESSION_STREAM_DECODE, algorithm: COMPRESSION_ZLIB)
            return perform(config, source: ptr.advanced(by: pos), sourceSize: limit - pos)
        }

        guard let inflated = cresult else { return nil }
        guard ftr.isize == UInt32(truncatingIfNeeded: inflated.count) else { return nil }
        guard ftr.crc32 == inflated.crc32().checksum else { return nil }
        return inflated
    }

    /// Calculate the Adler32 checksum of the data.
    /// - returns: Adler32 checksum type. Can still be further advanced.
    func adler32() -> Adler32 {
        var res = Adler32()
        res.advance(withChunk: self)
        return res
    }

    /// Calculate the Crc32 checksum of the data.
    /// - returns: Crc32 checksum type. Can still be further advanced.
    func crc32() -> Crc32 {
        var res = Crc32()
        res.advance(withChunk: self)
        return res
    }
}

/// Struct based type representing a Crc32 checksum.
public struct Crc32: CustomStringConvertible {
    private static let zLibCrc32: ZLibCrc32FuncPtr? = loadCrc32fromZLib()

    public init() {}

    // C convention function pointer type matching the signature of `libz::crc32`
    private typealias ZLibCrc32FuncPtr = @convention(c) (
        _ cks: UInt32,
        _ buf: UnsafePointer<UInt8>,
        _ len: UInt32
    ) -> UInt32

    /// Raw checksum. Updated after a every call to `advance(withChunk:)`
    public var checksum: UInt32 = 0

    /// Advance the current checksum with a chunk of data. Designed t be called multiple times.
    /// - parameter chunk: data to advance the checksum
    public mutating func advance(withChunk chunk: Data) {
        if let fastCrc32 = Crc32.zLibCrc32 {
            checksum = chunk.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> UInt32 in
                fastCrc32(checksum, ptr, UInt32(chunk.count))
            }
        } else {
            checksum = slowCrc32(start: checksum, data: chunk)
        }
    }

    /// Formatted checksum.
    public var description: String {
        String(format: "%08x", checksum)
    }

    /// Load `crc32()` from '/usr/lib/libz.dylib' if libz is installed.
    /// - returns: A function pointer to crc32() of zlib or nil if zlib can't be found
    private static func loadCrc32fromZLib() -> ZLibCrc32FuncPtr? {
        guard let libz = dlopen("/usr/lib/libz.dylib", RTLD_NOW) else { return nil }
        guard let fptr = dlsym(libz, "crc32") else { return nil }
        return unsafeBitCast(fptr, to: ZLibCrc32FuncPtr.self)
    }

    /// Rudimentary fallback implementation of the crc32 checksum. This is only a backup used
    /// when zlib can't be found under '/usr/lib/libz.dylib'.
    /// - returns: crc32 checksum (4 byte)
    private func slowCrc32(start: UInt32, data: Data) -> UInt32 {
        ~data.reduce(~start) { (crc: UInt32, next: UInt8) -> UInt32 in
            let tableOffset = (crc ^ UInt32(next)) & 0xFF
            return lookUpTable[Int(tableOffset)] ^ crc >> 8
        }
    }

    /// Lookup table for faster crc32 calculation.
    /// table source: http://web.mit.edu/freebsd/head/sys/libkern/crc32.c
    private let lookUpTable: [UInt32] = [
        0x0000_0000, 0x7707_3096, 0xEE0E_612C, 0x9909_51BA, 0x076D_C419, 0x706A_F48F, 0xE963_A535, 0x9E64_95A3,
        0x0EDB_8832, 0x79DC_B8A4, 0xE0D5_E91E, 0x97D2_D988, 0x09B6_4C2B, 0x7EB1_7CBD, 0xE7B8_2D07, 0x90BF_1D91,
        0x1DB7_1064, 0x6AB0_20F2, 0xF3B9_7148, 0x84BE_41DE, 0x1ADA_D47D, 0x6DDD_E4EB, 0xF4D4_B551, 0x83D3_85C7,
        0x136C_9856, 0x646B_A8C0, 0xFD62_F97A, 0x8A65_C9EC, 0x1401_5C4F, 0x6306_6CD9, 0xFA0F_3D63, 0x8D08_0DF5,
        0x3B6E_20C8, 0x4C69_105E, 0xD560_41E4, 0xA267_7172, 0x3C03_E4D1, 0x4B04_D447, 0xD20D_85FD, 0xA50A_B56B,
        0x35B5_A8FA, 0x42B2_986C, 0xDBBB_C9D6, 0xACBC_F940, 0x32D8_6CE3, 0x45DF_5C75, 0xDCD6_0DCF, 0xABD1_3D59,
        0x26D9_30AC, 0x51DE_003A, 0xC8D7_5180, 0xBFD0_6116, 0x21B4_F4B5, 0x56B3_C423, 0xCFBA_9599, 0xB8BD_A50F,
        0x2802_B89E, 0x5F05_8808, 0xC60C_D9B2, 0xB10B_E924, 0x2F6F_7C87, 0x5868_4C11, 0xC161_1DAB, 0xB666_2D3D,
        0x76DC_4190, 0x01DB_7106, 0x98D2_20BC, 0xEFD5_102A, 0x71B1_8589, 0x06B6_B51F, 0x9FBF_E4A5, 0xE8B8_D433,
        0x7807_C9A2, 0x0F00_F934, 0x9609_A88E, 0xE10E_9818, 0x7F6A_0DBB, 0x086D_3D2D, 0x9164_6C97, 0xE663_5C01,
        0x6B6B_51F4, 0x1C6C_6162, 0x8565_30D8, 0xF262_004E, 0x6C06_95ED, 0x1B01_A57B, 0x8208_F4C1, 0xF50F_C457,
        0x65B0_D9C6, 0x12B7_E950, 0x8BBE_B8EA, 0xFCB9_887C, 0x62DD_1DDF, 0x15DA_2D49, 0x8CD3_7CF3, 0xFBD4_4C65,
        0x4DB2_6158, 0x3AB5_51CE, 0xA3BC_0074, 0xD4BB_30E2, 0x4ADF_A541, 0x3DD8_95D7, 0xA4D1_C46D, 0xD3D6_F4FB,
        0x4369_E96A, 0x346E_D9FC, 0xAD67_8846, 0xDA60_B8D0, 0x4404_2D73, 0x3303_1DE5, 0xAA0A_4C5F, 0xDD0D_7CC9,
        0x5005_713C, 0x2702_41AA, 0xBE0B_1010, 0xC90C_2086, 0x5768_B525, 0x206F_85B3, 0xB966_D409, 0xCE61_E49F,
        0x5EDE_F90E, 0x29D9_C998, 0xB0D0_9822, 0xC7D7_A8B4, 0x59B3_3D17, 0x2EB4_0D81, 0xB7BD_5C3B, 0xC0BA_6CAD,
        0xEDB8_8320, 0x9ABF_B3B6, 0x03B6_E20C, 0x74B1_D29A, 0xEAD5_4739, 0x9DD2_77AF, 0x04DB_2615, 0x73DC_1683,
        0xE363_0B12, 0x9464_3B84, 0x0D6D_6A3E, 0x7A6A_5AA8, 0xE40E_CF0B, 0x9309_FF9D, 0x0A00_AE27, 0x7D07_9EB1,
        0xF00F_9344, 0x8708_A3D2, 0x1E01_F268, 0x6906_C2FE, 0xF762_575D, 0x8065_67CB, 0x196C_3671, 0x6E6B_06E7,
        0xFED4_1B76, 0x89D3_2BE0, 0x10DA_7A5A, 0x67DD_4ACC, 0xF9B9_DF6F, 0x8EBE_EFF9, 0x17B7_BE43, 0x60B0_8ED5,
        0xD6D6_A3E8, 0xA1D1_937E, 0x38D8_C2C4, 0x4FDF_F252, 0xD1BB_67F1, 0xA6BC_5767, 0x3FB5_06DD, 0x48B2_364B,
        0xD80D_2BDA, 0xAF0A_1B4C, 0x3603_4AF6, 0x4104_7A60, 0xDF60_EFC3, 0xA867_DF55, 0x316E_8EEF, 0x4669_BE79,
        0xCB61_B38C, 0xBC66_831A, 0x256F_D2A0, 0x5268_E236, 0xCC0C_7795, 0xBB0B_4703, 0x2202_16B9, 0x5505_262F,
        0xC5BA_3BBE, 0xB2BD_0B28, 0x2BB4_5A92, 0x5CB3_6A04, 0xC2D7_FFA7, 0xB5D0_CF31, 0x2CD9_9E8B, 0x5BDE_AE1D,
        0x9B64_C2B0, 0xEC63_F226, 0x756A_A39C, 0x026D_930A, 0x9C09_06A9, 0xEB0E_363F, 0x7207_6785, 0x0500_5713,
        0x95BF_4A82, 0xE2B8_7A14, 0x7BB1_2BAE, 0x0CB6_1B38, 0x92D2_8E9B, 0xE5D5_BE0D, 0x7CDC_EFB7, 0x0BDB_DF21,
        0x86D3_D2D4, 0xF1D4_E242, 0x68DD_B3F8, 0x1FDA_836E, 0x81BE_16CD, 0xF6B9_265B, 0x6FB0_77E1, 0x18B7_4777,
        0x8808_5AE6, 0xFF0F_6A70, 0x6606_3BCA, 0x1101_0B5C, 0x8F65_9EFF, 0xF862_AE69, 0x616B_FFD3, 0x166C_CF45,
        0xA00A_E278, 0xD70D_D2EE, 0x4E04_8354, 0x3903_B3C2, 0xA767_2661, 0xD060_16F7, 0x4969_474D, 0x3E6E_77DB,
        0xAED1_6A4A, 0xD9D6_5ADC, 0x40DF_0B66, 0x37D8_3BF0, 0xA9BC_AE53, 0xDEBB_9EC5, 0x47B2_CF7F, 0x30B5_FFE9,
        0xBDBD_F21C, 0xCABA_C28A, 0x53B3_9330, 0x24B4_A3A6, 0xBAD0_3605, 0xCDD7_0693, 0x54DE_5729, 0x23D9_67BF,
        0xB366_7A2E, 0xC461_4AB8, 0x5D68_1B02, 0x2A6F_2B94, 0xB40B_BE37, 0xC30C_8EA1, 0x5A05_DF1B, 0x2D02_EF8D,
    ]
}

/// Struct based type representing a Adler32 checksum.
public struct Adler32: CustomStringConvertible {
    private static let zLibAdler32: ZLibAdler32FuncPtr? = loadAdler32fromZLib()

    public init() {}

    // C convention function pointer type matching the signature of `libz::adler32`
    private typealias ZLibAdler32FuncPtr = @convention(c) (
        _ cks: UInt32,
        _ buf: UnsafePointer<UInt8>,
        _ len: UInt32
    ) -> UInt32

    /// Raw checksum. Updated after a every call to `advance(withChunk:)`
    public var checksum: UInt32 = 1

    /// Advance the current checksum with a chunk of data. Designed t be called multiple times.
    /// - parameter chunk: data to advance the checksum
    public mutating func advance(withChunk chunk: Data) {
        if let fastAdler32 = Adler32.zLibAdler32 {
            checksum = chunk.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> UInt32 in
                fastAdler32(checksum, ptr, UInt32(chunk.count))
            }
        } else {
            checksum = slowAdler32(start: checksum, data: chunk)
        }
    }

    /// Formatted checksum.
    public var description: String {
        String(format: "%08x", checksum)
    }

    /// Load `adler32()` from '/usr/lib/libz.dylib' if libz is installed.
    /// - returns: A function pointer to adler32() of zlib or nil if zlib can't be found
    private static func loadAdler32fromZLib() -> ZLibAdler32FuncPtr? {
        guard let libz = dlopen("/usr/lib/libz.dylib", RTLD_NOW) else { return nil }
        guard let fptr = dlsym(libz, "adler32") else { return nil }
        return unsafeBitCast(fptr, to: ZLibAdler32FuncPtr.self)
    }

    /// Rudimentary fallback implementation of the adler32 checksum. This is only a backup used
    /// when zlib can't be found under '/usr/lib/libz.dylib'.
    /// - returns: adler32 checksum (4 byte)
    private func slowAdler32(start: UInt32, data: Data) -> UInt32 {
        var s1: UInt32 = start & 0xFFFF
        var s2: UInt32 = (start >> 16) & 0xFFFF
        let prime: UInt32 = 65521

        for byte in data {
            s1 += UInt32(byte)
            if s1 >= prime { s1 = s1 % prime }
            s2 += s1
            if s2 >= prime { s2 = s2 % prime }
        }
        return (s2 << 16) | s1
    }
}

private extension Data {
    func withUnsafeBytes<ResultType, ContentType>(_ body: (UnsafePointer<ContentType>) throws -> ResultType) rethrows -> ResultType
    {
        try withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) -> ResultType in
            try body(rawBufferPointer.bindMemory(to: ContentType.self).baseAddress!)
        }
    }
}

private extension Data.CompressionAlgorithm {
    var lowLevelType: compression_algorithm {
        switch self {
        case .zlib: return COMPRESSION_ZLIB
        case .lzfse: return COMPRESSION_LZFSE
        case .lz4: return COMPRESSION_LZ4
        case .lzma: return COMPRESSION_LZMA
        }
    }
}

private typealias Config = (operation: compression_stream_operation, algorithm: compression_algorithm)

private func perform(_ config: Config, source: UnsafePointer<UInt8>, sourceSize: Int, preload: Data = Data()) -> Data?
{
    guard config.operation == COMPRESSION_STREAM_ENCODE || sourceSize > 0 else { return nil }

    let streamBase = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
    defer { streamBase.deallocate() }
    var stream = streamBase.pointee

    let status = compression_stream_init(&stream, config.operation, config.algorithm)
    guard status != COMPRESSION_STATUS_ERROR else { return nil }
    defer { compression_stream_destroy(&stream) }

    var result = preload
    var flags = Int32(COMPRESSION_STREAM_FINALIZE.rawValue)
    let blockLimit = 64 * 1024
    var bufferSize = Swift.max(sourceSize, 64)

    if sourceSize > blockLimit {
        bufferSize = blockLimit
        if config.algorithm == COMPRESSION_LZFSE, config.operation != COMPRESSION_STREAM_ENCODE {
            // This fixes a bug in Apples lzfse decompressor. it will sometimes fail randomly when the input gets
            // splitted into multiple chunks and the flag is not 0. Even though it should always work with FINALIZE...
            flags = 0
        }
    }

    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    stream.dst_ptr = buffer
    stream.dst_size = bufferSize
    stream.src_ptr = source
    stream.src_size = sourceSize

    while true {
        switch compression_stream_process(&stream, flags) {
        case COMPRESSION_STATUS_OK:
            guard stream.dst_size == 0 else { return nil }
            result.append(buffer, count: stream.dst_ptr - buffer)
            stream.dst_ptr = buffer
            stream.dst_size = bufferSize

            if flags == 0, stream.src_size == 0 { // part of the lzfse bugfix above
                flags = Int32(COMPRESSION_STREAM_FINALIZE.rawValue)
            }

        case COMPRESSION_STATUS_END:
            result.append(buffer, count: stream.dst_ptr - buffer)
            return result

        default:
            return nil
        }
    }
}
