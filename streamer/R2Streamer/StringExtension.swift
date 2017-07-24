//
//  StringExtension.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

extension String {

    var ns: NSString {
        return self as NSString
    }

    func appending(pathComponent: String) -> String {
        return (self as NSString).appendingPathComponent(pathComponent)
    }

    var deletingLastPathComponent: String {
        return ns.deletingLastPathComponent
    }

    var lastPathComponent: String {
        return ns.lastPathComponent
    }

    var pathExtension: String {
        return ns.pathExtension
    }

    /// Date string (ISO8601) to Date object.
    var dateFromISO8601: Date? {
        return Formatter.iso8601.date(from: self)   //  2012-01-20T12:47:00Z -> "Mar 22, 2017, 10:22 AM"
    }

    func endIndex(of string: String, options: CompareOptions = .literal) -> Index? {
        return range(of: string, options: options)?.upperBound
    }

    func startIndex(of string: String, options: CompareOptions = .literal) -> Index? {
        return range(of: string, options: options)?.lowerBound
    }

    func insert(string: String, at index: String.Index) -> String {
        let prefix = substring(to: index)
        let suffix = substring(from: index)

        return  prefix + string + suffix
    }
}
