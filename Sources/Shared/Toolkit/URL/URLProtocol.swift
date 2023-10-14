//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A type that can represent a URL.
public protocol URLProtocol {
    
    /// Creates a new instance of this type from a Foundation `URL`.
    init?(url: URL)

    /// Returns a foundation `URL` for this URL representation.
    var url: URL { get }

    /// Returns the string representation for this URL.
    var string: String { get }

    /// Decoded path segments identifying a location.
    var path: String? { get }

    /// Returns a copy of this URL after appending path components.
    func appendingPath(_ path: String) -> Self?

    /// Returns the decoded query parameters present in this URL, in the order
    /// they appear.
    var query: URLQuery { get }

    /// Creates a copy of this URL after removing its query portion.
    func removingQuery() -> Self?

    /// Creates a copy of this URL after removing its fragment portion.
    func removingFragment() -> Self?
}

public extension URLProtocol {
    var string: String { url.absoluteString }

    var path: String? {
        // We can't use `url.path`, see https://openradar.appspot.com/28357201
        components?.path.orNilIfEmpty()
    }

    func appendingPath(_ path: String) -> Self? {
        guard !path.isEmpty else {
            return self
        }

        return Self(url: url.appendingPathComponent(path, isDirectory: path.hasSuffix("/")))
    }

    var query: URLQuery { URLQuery(url: url) }

    func removingQuery() -> Self? {
        guard let url = url.copy({ $0.query = nil }) else {
            return nil
        }
        return Self(url: url)
    }

    func removingFragment() -> Self? {
        guard let url = url.copy({ $0.fragment = nil }) else {
            return nil
        }
        return Self(url: url)
    }

    fileprivate var components: URLComponents? {
        URLComponents(url: url, resolvingAgainstBaseURL: true)
    }
}
