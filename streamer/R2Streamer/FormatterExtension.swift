//
//  FormatterExtension.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/22/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

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
