//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// A type that can represent a URL.
public protocol URLProtocol: CustomStringConvertible {
    /// Creates a new instance of this type from a Foundation `URL`.
    init?(url: URL)

    /// Returns a foundation `URL` for this URL representation.
    var url: URL { get }

    /// Returns the string representation for this URL.
    var string: String { get }

    /// Decoded path segments identifying a location.
    var path: String? { get }

    /// The last path component of the receiver.
    var lastPathComponent: String? { get }

    /// The path extension, or nil if it is empty.
    var pathExtension: String? { get }

    /// Returns a copy of this URL after appending path components.
    func appendingPath(_ path: String) -> Self?

    /// Returns a copy of this URL after appending path components.
    func appendingPath(_ path: String, isDirectory: Bool) -> Self?

    /// Returns the decoded query parameters present in this URL, in the order
    /// they appear.
    var query: URLQuery { get }

    /// Creates a copy of this URL after removing its query portion.
    func removingQuery() -> Self?

    /// Returns the decoded fragment portion of this URL, if there's any.
    var fragment: String? { get }

    /// Creates a copy of this URL after removing its fragment portion.
    func removingFragment() -> Self?
}

public extension URLProtocol {
    init?(string: String) {
        guard let url = URL(percentEncodedString: string) else {
            return nil
        }
        self.init(url: url)
    }

    var string: String { url.absoluteString }

    var description: String { string }

    var path: String? {
        // We can't use `url.path`, see https://openradar.appspot.com/28357201
        components?.path.orNilIfEmpty()
    }

    var lastPathComponent: String? {
        url.lastPathComponent.orNilIfEmpty()
    }

    var pathExtension: String? {
        url.pathExtension.orNilIfEmpty()
    }

    func appendingPath(_ path: String) -> Self? {
        appendingPath(path, isDirectory: path.hasSuffix("/"))
    }

    func appendingPath(_ path: String, isDirectory: Bool) -> Self? {
        guard !path.isEmpty else {
            return self
        }

        return Self(url: url.appendingPathComponent(path, isDirectory: isDirectory))
    }

    var query: URLQuery { URLQuery(url: url) }

    func removingQuery() -> Self? {
        guard let url = url.copy({ $0.query = nil }) else {
            return nil
        }
        return Self(url: url)
    }

    var fragment: String? { url.fragment?.orNilIfEmpty() }

    func removingFragment() -> Self? {
        guard let url = url.copy({ $0.fragment = nil }) else {
            return nil
        }
        return Self(url: url)
    }

    private var components: URLComponents? {
        URLComponents(url: url, resolvingAgainstBaseURL: true)
    }
}
