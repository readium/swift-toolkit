//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension URL {
    /// Removes the fragment portion of the receiver and returns it.
    mutating func removeFragment() -> String? {
        var fragment: String?
        guard let result = copy({
            fragment = $0.fragment
            $0.fragment = nil
        }) else {
            return nil
        }
        self = result
        return fragment
    }

    /// Creates a copy of the receiver after removing its fragment portion.
    func removingFragment() -> URL? {
        copy { $0.fragment = nil }
    }

    /// Creates a copy of the receiver after modifying its components.
    func copy(_ changes: (inout URLComponents) -> Void) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return nil
        }
        changes(&components)
        return components.url
    }

    /// Returns the first available URL by appending the given `pathComponent`.
    ///
    /// If `pathComponent` is already taken, then it appends a number to it.
    func appendingUniquePathSegment(_ pathComponent: String? = nil) async -> URL {
        /// Returns the first path component matching the given `validation` closure.
        /// Numbers are appended to the path component until a valid candidate is found.
        func uniquify(_ pathComponent: String?, validation: (String) -> Bool) async -> String {
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

        let pathComponent = await uniquify(pathComponent) { candidate in
            let destination = appendingPathComponent(candidate)
            return !((try? destination.checkResourceIsReachable()) ?? false)
        }

        return appendingPathComponent(pathComponent)
    }

    /// Adds the given `newScheme` to the URL, but only if the URL doesn't already have one.
    func addingSchemeWhenMissing(_ newScheme: String) -> URL {
        guard scheme == nil else {
            return self
        }

        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        components?.scheme = newScheme
        return components?.url ?? self
    }
}
