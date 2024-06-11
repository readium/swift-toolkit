//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a relative URL.
public struct RelativeURL: URLProtocol, Hashable {
    public let url: URL

    /// Creates a ``RelativeURL`` from a standard Swift ``URL``.
    public init?(url: URL) {
        guard url.scheme == nil else {
            return nil
        }

        self.url = url.absoluteURL
    }

    /// Creates a ``RelativeURL`` from a percent-decoded path.
    public init?(path: String) {
        guard let url = URL(path: path) else {
            return nil
        }
        self.init(url: url)
    }

    /// Resolves the `other` URL to this URL, if possible.
    ///
    /// For example:
    ///     self: foo/bar
    ///     other: baz
    ///     returns foo/baz
    public func resolve<T: URLConvertible>(_ other: T) -> AnyURL? {
        // other is absolute?
        guard let relativeURL = other.relativeURL else {
            return other.anyURL
        }
        return resolve(relativeURL)?.anyURL
    }

    /// Resolves the `other` URL to this URL, if possible.
    ///
    /// For example:
    ///     self: foo/bar
    ///     other: baz
    ///     returns foo/baz
    public func resolve(_ other: RelativeURL) -> RelativeURL? {
        guard !other.string.hasPrefix("/") else {
            return other
        }

        guard var path = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        if !other.path.isEmpty, !path.hasSuffix("/") {
            path = url.deletingLastPathComponent().path.addingSuffix("/")
        }

        guard
            let otherComponents = URLComponents(url: other.url, resolvingAgainstBaseURL: true),
            var resolvedComponents = URLComponents(string: path + other.string)
        else {
            return nil
        }

        resolvedComponents.fragment = otherComponents.fragment
        resolvedComponents.query = otherComponents.query

        guard let resolvedURL = resolvedComponents.url?.standardized else {
            return nil
        }

        return RelativeURL(url: resolvedURL)
    }

    /// Relativizes the `other` URL against this relative URL, if possible.
    ///
    /// For example:
    ///     self: foo/bar
    ///     other: foo/bar/baz
    ///     returns baz
    public func relativize<T: URLConvertible>(_ other: T) -> RelativeURL? {
        guard
            let relativeURL = other.relativeURL,
            relativeURL.string.hasPrefix(string)
        else {
            return nil
        }

        return RelativeURL(
            string: relativeURL.string
                .removingPrefix(string)
                .removingPrefix("/")
        )
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
        hasher.combine(query)
        hasher.combine(fragment)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.path == rhs.path
            && lhs.query == rhs.query
            && lhs.fragment == rhs.fragment
    }
}

/// Implements `URLConvertible`.
extension RelativeURL: URLConvertible {
    public var anyURL: AnyURL { .relative(self) }
    public var relativeURL: RelativeURL? { self }
    public var absoluteURL: AbsoluteURL? { nil }
}
