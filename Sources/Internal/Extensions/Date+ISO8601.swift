//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension Date {
    var iso8601: String {
        DateFormatter.iso8601.string(from: self)
    }
}

public extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()

    static func iso8601Formatter(for string: String) -> DateFormatter {
        // https://developer.apple.com/documentation/foundation/dateformatter
        // Doesn't support millisecond or uncompleted part for date, time, timezone offset.
        let formats = [
            4: "yyyy",
            7: "yyyy-MM",
            10: "yyyy-MM-dd",
            11: "yyyy-MM-ddZ",
            16: "yyyy-MM-ddZZZZZ",
            19: "yyyy-MM-dd'T'HH:mm:ss",
            25: "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
        ]
        let defaultFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        let format = formats[string.count] ?? defaultFormat
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }
}

public extension String {
    var dateFromISO8601: Date? {
        // Removing .SSSS precision if found.
        var string = self
        let regexp = "[.][0-9]+"

        if let range = string.range(of: regexp, options: .regularExpression) {
            string.replaceSubrange(range, with: "")
        }

        return DateFormatter.iso8601Formatter(for: string).date(from: string)
    }
}
