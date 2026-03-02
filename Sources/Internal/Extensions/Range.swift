//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension Range where Bound == UInt64 {
    func clampedToInt() -> Range<UInt64> {
        clamped(to: 0 ..< UInt64(Int.max))
    }

    /// Parses an HTTP `Range` header value (RFC 7233) into a byte range.
    ///
    /// Supports:
    /// - `bytes=0-1023` → `0..<1024`
    /// - `bytes=1024-`  → `1024..<totalLength`
    /// - `bytes=-512`   → `(totalLength-512)..<totalLength`
    ///
    /// Returns `nil` if the value is absent, malformed, or out of bounds.
    init?(httpRange header: String, in totalLength: UInt64) {
        guard header.hasPrefix("bytes=") else {
            return nil
        }

        let spec = header.dropFirst("bytes=".count)

        // Suffix range: bytes=-N
        if spec.hasPrefix("-") {
            guard let suffix = UInt64(spec.dropFirst()), suffix > 0 else { return nil }
            let start = totalLength > suffix ? totalLength - suffix : 0
            self = start ..< totalLength
            return
        }

        let parts = spec.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let start = UInt64(parts[0]) else { return nil }

        if parts[1].isEmpty {
            // Open-ended range: bytes=N-
            guard start < totalLength else { return nil }
            self = start ..< totalLength
            return
        }

        // Closed range: bytes=N-M
        guard let end = UInt64(parts[1]), end >= start else { return nil }
        let clampedEnd = Swift.min(end + 1, totalLength)
        guard start < clampedEnd else { return nil }
        self = start ..< clampedEnd
    }
}
