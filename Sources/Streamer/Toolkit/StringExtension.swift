//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension String {
    var ns: NSString {
        self as NSString
    }

    func appending(pathComponent: String) -> String {
        (self as NSString).appendingPathComponent(pathComponent)
    }

    var deletingLastPathComponent: String {
        ns.deletingLastPathComponent
    }

    var lastPathComponent: String {
        ns.lastPathComponent
    }

    var pathExtension: String {
        ns.pathExtension
    }

    func endIndex(of string: String, options: CompareOptions = .literal) -> Index? {
        range(of: string, options: options)?.upperBound
    }

    func startIndex(of string: String, options: CompareOptions = .literal) -> Index? {
        range(of: string, options: options)?.lowerBound
    }

    func insert(string: String, at index: String.Index) -> String {
        let prefix = self[..<index] // substring(to: index)
        let suffix = self[index...] // substring(from: index)

        return prefix + string + suffix
    }
}
