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

    func endIndex(of string: String, options: CompareOptions = .literal) -> Index? {
        return range(of: string, options: options)?.upperBound
    }

    func startIndex(of string: String, options: CompareOptions = .literal) -> Index? {
        return range(of: string, options: options)?.lowerBound
    }

    func insert(string: String, at index: String.Index) -> String {
        let prefix = self[..<index] //substring(to: index)
        let suffix = self[index...] //substring(from: index)

        return  prefix + string + suffix
    }
}
