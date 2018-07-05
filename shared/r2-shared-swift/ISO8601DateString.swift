//
//  DateExtension.swift
//  R2Shared
//
//  Created by Alexandre Camilleri on 3/22/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public extension Date {
    /// Computed property turning an ISO8601 Date to a String?.
    public var iso8601: String {
        return Formatter.iso8601.string(from: self)
    }
}

public extension Formatter {
    /// Format from the ISO8601 format to a Date format.
    public static let iso8601: DateFormatter = {
        let formatter = DateFormatter()

        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()
}

public extension String {
    /// Date string (ISO8601) to Date object.
    public var dateFromISO8601: Date? {
        // Removing .SSSS precision if found.
        var string = self
        let regexp = "[.][0-9]+"

        if let range = string.range(of: regexp, options: .regularExpression) {
            string.replaceSubrange(range, with: "")
        }

        return Formatter.iso8601.date(from: string)   //  2012-01-20T12:47:00.SSSZ -> "Mar 22, 2017, 10:22 AM"
    }
}
