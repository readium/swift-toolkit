//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CommonCrypto
import Foundation

extension URL: Loggable {
    /// Indicates whether this URL is an HTTP or HTTPS URL.
    @available(*, unavailable, message: "Copy the implementation in your app if you need it")
    public var isHTTP: Bool {
        ["http", "https"].contains(scheme?.lowercased())
    }

    /// Returns whether the given `url` is `self` or one of its descendants.
    @available(*, unavailable, message: "Copy the implementation in your app if you need it")
    public func isParentOf(_ url: URL) -> Bool {
        let standardizedSelf = standardizedFileURL.path
        let other = url.standardizedFileURL.path
        return standardizedSelf == other || other.hasPrefix(standardizedSelf + "/")
    }

    /// Computes the MD5 hash of the file, if the URL is a file URL.
    /// Source: https://stackoverflow.com/a/42935601/1474476
    @available(*, unavailable)
    public func md5() -> String? { fatalError() }

    /// Returns the first available URL by appending the given `pathComponent`.
    ///
    /// If `pathComponent` is already taken, then it appends a number to it.
    @available(*, unavailable, message: "Copy the implementation in your app if you need it")
    public func appendingUniquePathComponent(_ pathComponent: String? = nil) -> URL {
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

    /// Adds the given `newScheme` to the URL, but only if the URL doesn't already have one.
    @available(*, unavailable, message: "Copy the implementation in your app if you need it")
    public func addingSchemeIfMissing(_ newScheme: String) -> URL {
        guard scheme == nil else {
            return self
        }

        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        components?.scheme = newScheme
        return components?.url ?? self
    }
}
