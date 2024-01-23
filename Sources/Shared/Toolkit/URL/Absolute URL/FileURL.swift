//
//  Copyright 2024 Readium Foundation. All rights reserved.
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
            // We can't use `url.path`, see https://openradar.appspot.com/28357201
            let path = URLComponents(url: url, resolvingAgainstBaseURL: true)?.path,
            !path.isEmpty
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

    public var lastPathSegment: String {
        url.lastPathComponent
    }

    /// Returns whether the given `url` is `self` or one of its descendants.
    public func isParent(of other: FileURL) -> Bool {
        path == other.path || other.path.hasPrefix(path.addingSuffix("/"))
    }

    /// Returns whether the file exists on the file system.
    // FIXME: Async
    public func exists() throws -> Bool {
        try url.checkResourceIsReachable()
    }

    /// Returns whether the file is a directory.
    // FIXME: Async
    public func isDirectory() throws -> Bool {
        try (url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
}

public extension URLConvertible {
    /// Returns a `FileURL` if the URL has a `file` scheme.
    var fileURL: FileURL? {
        (absoluteURL as? FileURL) ?? FileURL(url: anyURL.url)
    }
}
