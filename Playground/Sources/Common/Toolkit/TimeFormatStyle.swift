//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

// FIXME: Use Duration API when bumping to iOS 16.

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
    static var time: TimeFormatStyle {
        TimeFormatStyle()
    }
}
