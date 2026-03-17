//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

// FIXME: Use Duration API when bumping to iOS 16.

/// A `FormatStyle` that converts a `Double` (seconds) into a compact
/// human-readable duration string (e.g. `"1h 23m 45s"`).
struct TimeFormatStyle: FormatStyle {
    typealias FormatInput = Double
    typealias FormatOutput = String?

    func format(_ value: Double) -> String? {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: value)
    }
}

extension FormatStyle where Self == TimeFormatStyle {
    /// Convenience accessor: `someDouble.formatted(.time)`.
    static var time: TimeFormatStyle {
        TimeFormatStyle()
    }
}
