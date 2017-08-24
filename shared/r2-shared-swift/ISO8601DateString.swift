//
//  DateExtension.swift
//  R2Shared
//
//  Created by Alexandre Camilleri on 3/22/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

extension Date {
    /// Computed property turning an ISO8601 Date to a String?.
    var iso8601: String {
        return Formatter.iso8601.string(from: self)
    }
}

extension Formatter {
    /// Format from the ISO8601 format to a Date format.
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()

        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()
}

extension String {
    /// Date string (ISO8601) to Date object.
    var dateFromISO8601: Date? {
        return Formatter.iso8601.date(from: self)   //  2012-01-20T12:47:00Z -> "Mar 22, 2017, 10:22 AM"
    }
}
