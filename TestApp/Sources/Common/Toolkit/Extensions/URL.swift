//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension URL {
    /// Returns the first available URL by appending the given `pathComponent`.
    ///
    /// If `pathComponent` is already taken, then it appends a number to it.
    func appendingUniquePathComponent(_ pathComponent: String? = nil) -> URL {
        /// Returns the first path component matching the given `validation` closure.
        /// Numbers are appended to the path component until a valid candidate is found.
        func uniquify(_ pathComponent: String?, validation: (String) -> Bool) -> String {
            let pathComponent = pathComponent ?? UUID().uuidString
            var ext = (pathComponent as NSString).pathExtension
            if !ext.isEmpty {
                ext = ".\(ext)"
            }
            let pathComponentWithoutExtension = (pathComponent as NSString).deletingPathExtension

            var candidate = pathComponent
            var i = 0
            while !validation(candidate) {
                i += 1
                candidate = "\(pathComponentWithoutExtension) \(i)\(ext)"
            }
            return candidate
        }

        let pathComponent = uniquify(pathComponent) { candidate in
            let destination = appendingPathComponent(candidate)
            return !((try? destination.checkResourceIsReachable()) ?? false)
        }

        return appendingPathComponent(pathComponent)
    }
}
