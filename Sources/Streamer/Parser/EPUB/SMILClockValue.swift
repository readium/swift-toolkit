//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Parses a SMIL clock value string into seconds.
/// https://www.w3.org/TR/SMIL/smil-timing.html#Timing-ClockValueSyntax
func parseSmilClockValue(_ value: String) -> Double? {
    let s = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return nil }

    // Timecount values: Nh, Nmin, Ns, Nms, N
    let timecountPatterns: [(suffix: String, multiplier: Double)] = [
        ("h", 3600),
        ("min", 60),
        ("ms", 0.001),
        ("s", 1),
    ]
    for (suffix, multiplier) in timecountPatterns {
        if s.hasSuffix(suffix) {
            let numStr = String(s.dropLast(suffix.count))
            if let n = Double(numStr) {
                return n * multiplier
            }
        }
    }

    // Clock values: [[hh:]mm:]ss[.fraction]
    let parts = s.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
    switch parts.count {
    case 2:
        // mm:ss[.fraction]
        guard let mm = Double(parts[0]), let ss = Double(parts[1]) else { return nil }
        return mm * 60 + ss
    case 3:
        // hh:mm:ss[.fraction]
        guard let hh = Double(parts[0]), let mm = Double(parts[1]), let ss = Double(parts[2]) else { return nil }
        return hh * 3600 + mm * 60 + ss
    default:
        // Plain number (seconds)
        return Double(s)
    }
}
