//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumLCP
import ReadiumShared
import Testing

struct DataSHA256Tests {
    struct Decoding {
        @Test func hexadecimal() {
            #expect(Data(sha256: readiumDigestHex) == readiumDigest)
        }

        @Test func uppercaseHexadecimal() {
            #expect(Data(sha256: readiumDigestHex.uppercased()) == readiumDigest)
        }

        @Test func base64() {
            #expect(Data(sha256: readiumDigestBase64) == readiumDigest)
        }

        @Test func surroundingWhitespaceIsIgnored() {
            #expect(Data(sha256: " \(readiumDigestHex)\n") == readiumDigest)
            #expect(Data(sha256: " \(readiumDigestBase64)\n") == readiumDigest)
        }

        @Test(arguments: [
            "", // empty
            "not a hash",
            "0ea28c743883275f2454370a2e719a7f", // hex, too short (MD5 length)
            "0ea28c743883275f2454370a2e719a7f3d9f36116cd12c9c8e832d1f118a218b00", // hex, too long
            "zza28c743883275f2454370a2e719a7f3d9f36116cd12c9c8e832d1f118a218b", // 64 characters, but not hex nor valid base64
            "+126b3a0e22dfb6c7f894086e5f9653795f921e119c421580d2ec26d1796db32", // 64 characters, but a `+` sign accepted by `UInt8.init(_:radix:)` is not a hex digit
            "-126b3a0e22dfb6c7f894086e5f9653795f921e119c421580d2ec26d1796db32", // 64 characters, but a `-` sign accepted by `UInt8.init(_:radix:)` is not a hex digit
            "DqKMdDiDJ18kVDcKLnGafz2fNhE=", // valid base64, but not 32 bytes
        ])
        func invalidHash(string: String) {
            #expect(Data(sha256: string) == nil)
        }
    }

    struct FileDigest {
        @Test func computesTheDigestOfAFile() async throws {
            let file = try makeTemporaryFile(containing: Data("readium".utf8))
            defer { try? FileManager.default.removeItem(at: file.url) }

            let digest = try await Data.sha256(of: file)
            #expect(digest == readiumDigest)
        }

        @Test func computesTheDigestOfAnEmptyFile() async throws {
            let file = try makeTemporaryFile(containing: Data())
            defer { try? FileManager.default.removeItem(at: file.url) }

            let digest = try await Data.sha256(of: file)
            // SHA-256 of an empty input.
            #expect(digest == Data(sha256: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"))
        }

        @Test func computesTheDigestOfAFileLargerThanASingleChunk() async throws {
            // 2 MB, larger than the 512 KB read chunks.
            let data = Data(repeating: 0xAB, count: 2 * 1024 * 1024)
            let file = try makeTemporaryFile(containing: data)
            defer { try? FileManager.default.removeItem(at: file.url) }

            let digest = try await Data.sha256(of: file)
            #expect(digest == Data(sha256: "5e7c321a44769c5389419a685860088ec70bd6e28d8a5c68665cb8937ac305a0"))
        }

        @Test func failsIfTheFileDoesNotExist() async throws {
            let file = FileURL(url: URL(fileURLWithPath: "/does/not/exist-\(UUID().uuidString)"))!

            await #expect(throws: Error.self) {
                try await Data.sha256(of: file)
            }
        }
    }
}

// MARK: - Helpers

/// SHA-256 digest of the UTF-8 string "readium".
private let readiumDigest = Data([
    0x21, 0x26, 0xb3, 0xa0, 0xe2, 0x2d, 0xfb, 0x6c,
    0x7f, 0x89, 0x40, 0x86, 0xe5, 0xf9, 0x65, 0x37,
    0x95, 0xf9, 0x21, 0xe1, 0x19, 0xc4, 0x21, 0x58,
    0x0d, 0x2e, 0xc2, 0x6d, 0x17, 0x96, 0xdb, 0x32,
])

private let readiumDigestHex = "2126b3a0e22dfb6c7f894086e5f9653795f921e119c421580d2ec26d1796db32"
private let readiumDigestBase64 = "ISazoOIt+2x/iUCG5fllN5X5IeEZxCFYDS7CbReW2zI="

private func makeTemporaryFile(containing data: Data) throws -> FileURL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("DataSHA256Tests-\(UUID().uuidString)")
    try data.write(to: url)
    return FileURL(url: url)!
}
