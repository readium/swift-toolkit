//
//  StringExtension.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

extension String {
    func appending(pathComponent: String) -> String {
        return (self as NSString).appendingPathComponent(pathComponent)
    }

    func deletingLastPathComponent() -> String {
        return (self as NSString).deletingLastPathComponent
    }

    func lastPathComponent() -> String {
        return (self as NSString).lastPathComponent
    }

    /// Date string (ISO8601) to Date object.
    var dateFromISO8601: Date? {
        return Formatter.iso8601.date(from: self)   //  2012-01-20T12:47:00Z -> "Mar 22, 2017, 10:22 AM"
    }
}
