//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Parsed representation of an HTTP `Content-Range` response header.
public struct HTTPContentByteRange: Equatable, Sendable {
    /// Inclusive byte range of the response body within the full resource.
    ///
    /// `nil` when the range portion of the header is `*` (used in 416
    /// Range Not Satisfiable responses).
    public let range: ClosedRange<Int64>?

    /// Total size of the full resource in bytes.
    ///
    /// `nil` when the size portion of the header is `*` (total size unknown).
    public let size: Int64?

    public init(range: ClosedRange<Int64>?, size: Int64?) {
        self.range = range
        self.size = size
    }

    /// Parsed `Content-Range` header for this response, or `nil` if the header
    /// is incorrect.
    ///
    /// Covers all three spec-defined formats:
    /// - `bytes 0-100/1000` → `range: 0...100, size: 1000`
    /// - `bytes 0-100/*` → `range: 0...100, size: nil`
    /// - `bytes */1000` → `range: nil, size: 1000`
    public init?(header: String) {
        guard header.hasPrefix("bytes ") else {
            return nil
        }

        let parts = header.dropFirst("bytes ".count)
            .split(separator: "/", maxSplits: 1)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return nil }

        let rangeString = parts[0]
        let sizeString = parts[1]

        let size: Int64? = sizeString == "*" ? nil : Int64(sizeString)
        if let size, size < 0 {
            return nil
        }

        guard rangeString != "*" else {
            self.init(range: nil, size: size)
            return
        }

        let rangeParts = rangeString.split(separator: "-", maxSplits: 1)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard
            rangeParts.count == 2,
            let start = Int64(rangeParts[0]), start >= 0,
            let end = Int64(rangeParts[1]), end >= start
        else {
            return nil
        }

        self.init(range: start ... end, size: size)
    }
}
