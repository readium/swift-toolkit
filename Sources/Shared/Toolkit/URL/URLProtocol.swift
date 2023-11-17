//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// A type that can represent a URL.
public protocol URLProtocol: CustomStringConvertible, URLConvertible {
    /// Creates a new instance of this type from a Foundation `URL`.
    init?(url: URL)

    /// Returns a foundation `URL` for this URL representation.
    var url: URL { get }

    /// Returns the string representation for this URL.
    var string: String { get }

    /// Decoded path segments identifying a location.
    var path: String { get }

    /// Returns a copy of this URL after appending path components.
    func appendingPath(_ path: String, isDirectory: Bool) -> Self

    /// Returns the decoded path segments of the URL, or an empty array if the
    /// path is an empty string.
    var pathSegments: [String] { get }

    /// The last path segment of the URL.
    var lastPathSegment: String? { get }

    /// Returns a URL constructed by removing the last path component of self.
    func removingLastPathSegment() -> Self

    /// The path extension, or nil if it is empty.
    var pathExtension: String? { get }

    /// Returns a URL constructed by replacing or appending the given path
    /// extension to self.
    ///
    /// If the URL has an empty path (e.g., `http://www.example.com`), or a
    /// directory for last path segment, then this function will return the URL
    /// unchanged.
    func replacingPathExtension(_ pathExtension: String?) -> Self

    /// Returns the decoded query parameters present in this URL, in the order
    /// they appear.
    var query: URLQuery? { get }

    /// Creates a copy of this URL after removing its query portion.
    func removingQuery() -> Self

    /// Returns the decoded fragment portion of this URL, if there's any.
    var fragment: String? { get }

    /// Creates a copy of this URL after removing its fragment portion.
    func removingFragment() -> Self
}

public extension URLProtocol {
    init?(string: String) {
        guard let url = URL(percentEncodedString: string) else {
            return nil
        }
        self.init(url: url)
    }

    var string: String { url.absoluteString }

    var path: String {
        // We can't use `url.path`, see https://openradar.appspot.com/28357201
        components?.path ?? ""
    }

    func appendingPath(_ path: String, isDirectory: Bool) -> Self {
        let path = path.removingSuffix("/")
        guard !path.isEmpty else {
            return self
        }

        return Self(url: url.appendingPathComponent(path, isDirectory: isDirectory))!
    }

    var pathSegments: [String] {
        var comp = url.pathComponents
        if comp.first == "/" {
            comp.remove(at: 0)
        }
        return comp
    }

    var lastPathSegment: String? {
        url.lastPathComponent.orNilIfEmpty()
    }

    func removingLastPathSegment() -> Self {
        Self(url: url.deletingLastPathComponent())!
    }

    var pathExtension: String? {
        url.pathExtension.orNilIfEmpty()
    }

    func replacingPathExtension(_ pathExtension: String?) -> Self {
        guard !path.hasSuffix("/") else {
            return self
        }

        var url = url.deletingPathExtension()
        if let pathExtension = pathExtension {
            url = url.appendingPathExtension(pathExtension)
        }
        return Self(url: url)!
    }

    var query: URLQuery? { URLQuery(url: url) }

    func removingQuery() -> Self {
        if let url = url.copy({ $0.query = nil }) {
            return Self(url: url)!
        } else if let withoutQuery = string.components(separatedBy: "?").first {
            return Self(string: withoutQuery)!
        } else {
            return self
        }
    }

    var fragment: String? { url.fragment?.orNilIfEmpty()?.removingPercentEncoding }

    func removingFragment() -> Self {
        if let url = url.copy({ $0.fragment = nil }) {
            return Self(url: url)!
        } else if let withoutFragment = string.components(separatedBy: "#").first {
            return Self(string: withoutFragment)!
        } else {
            return self
        }
    }

    private var components: URLComponents? {
        URLComponents(url: url, resolvingAgainstBaseURL: true)
    }
}

/// Implements `CustomStringConvertible`
public extension URLProtocol {
    var description: String { string }
}
