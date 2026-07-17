//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CryptoKit
import Foundation
import ReadiumShared

extension Data {
    /// Parses a SHA-256 digest from its string representation.
    ///
    /// The LCP specification mandates a base 64 encoding, but the Readium
    /// LCP server historically produced hexadecimal digests, so both
    /// encodings are accepted.
    /// See https://github.com/readium/lcp-specs/issues/52
    init?(sha256: String) {
        let string = sha256.trimmingCharacters(in: .whitespacesAndNewlines)

        if string.count == 64, let digest = Data(hexadecimal: string) {
            self = digest
        } else if let digest = Data(base64Encoded: string), digest.count == SHA256.byteCount {
            self = digest
        } else {
            return nil
        }
    }

    /// Parses a string of hexadecimal digits into bytes.
    private init?(hexadecimal string: String) {
        // `UInt8.init(_:radix:)` accepts leading `+`/`-` signs, so we
        // explicitly restrict the alphabet to hexadecimal digits.
        guard
            string.count % 2 == 0,
            string.allSatisfy({ $0.isASCII && $0.isHexDigit })
        else {
            return nil
        }

        var data = Data(capacity: string.count / 2)
        var index = string.startIndex
        while index < string.endIndex {
            let nextIndex = string.index(index, offsetBy: 2)
            guard let byte = UInt8(string[index ..< nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }

        self = data
    }

    /// Computes the SHA-256 digest of the file at `file`, reading it in
    /// chunks to keep a low memory footprint.
    @concurrent static func sha256(of file: FileURL) async throws -> Data {
        let handle = try FileHandle(forReadingFrom: file.url)
        defer { try? handle.close() }

        var hasher = SHA256()
        let chunkSize = 512 * 1024

        while true {
            try Task.checkCancellation()
            guard let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty else {
                break
            }
            hasher.update(data: chunk)
            await Task.yield()
        }

        return Data(hasher.finalize())
    }
}
