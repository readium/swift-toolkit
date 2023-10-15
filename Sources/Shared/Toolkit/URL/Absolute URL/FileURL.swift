//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents an absolute URL with the special scheme `file`.
///
/// See https://url.spec.whatwg.org/#special-scheme
public struct FileURL: AbsoluteURL, Hashable {
    public init?(url: URL) {
        let url = url.standardizedFileURL
        guard
            let scheme = url.scheme.map(URLScheme.init(rawValue:)),
            scheme == .file,
            let path = url.path.orNilIfEmpty()
        else {
            return nil
        }

        self.path = path
        self.scheme = scheme
        self.url = url
    }

    /// Creates a file URL from a percent-decoded absolute path.
    public init?(path: String, isDirectory: Bool) {
        guard path != "/", !path.isEmpty, path.hasPrefix("/") else {
            return nil
        }
        self.init(url: URL(fileURLWithPath: path, isDirectory: isDirectory))
    }

    public let url: URL
    public let path: String
    public let scheme: URLScheme
    public let origin: String? = nil

    public var lastPathComponent: String { url.lastPathComponent }

    public func appendingPath(_ path: String) -> Self? {
        // The default strategy in `AbsoluteURL` doesn't work with file URLs.
        appendingPath(path, isDirectory: path.hasSuffix("/"))
    }

    /// Returns whether the given `url` is `self` or one of its descendants.
    public func isParent(of other: FileURL) -> Bool {
        path == other.path || other.path.hasPrefix(path + "/")
    }

    /// Returns whether the file exists on the file system.
    public func exists() throws -> Bool {
        try url.checkResourceIsReachable()
    }

    /// Returns whether the file is a directory.
    public func isDirectory() -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
}

public extension AbsoluteURL {
    /// Returns a `FileURL` if the URL has a `file` scheme.
    var fileURL: FileURL? {
        (self as? FileURL) ?? FileURL(url: url)
    }
}
