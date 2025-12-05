//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A type that can represent an absolute URL with a scheme.
public protocol AbsoluteURL: URLProtocol {
    /// Identifies the type of URL.
    var scheme: URLScheme { get }

    /// Origin of the URL.
    ///
    /// See https://url.spec.whatwg.org/#origin
    var origin: String? { get }
}

public extension AbsoluteURL {
    /// Host component of the URL, if any.
    var host: String? {
        url.host
    }

    /// Resolves the `other` URL to this URL, if possible.
    ///
    /// For example:
    ///     self: http://example.com/foo/
    ///     other: bar/baz
    ///     returns http://example.com/foo/bar/baz
    func resolve<T: URLConvertible>(_ other: T) -> AbsoluteURL? {
        switch other.anyURL {
        case let .relative(url):
            return resolve(url)
        case let .absolute(url):
            return url
        }
    }

    /// Resolves the `other` relative URL to this URL, if possible.
    ///
    /// For example:
    ///     self: http://example.com/foo/
    ///     other: bar/baz
    ///     returns http://example.com/foo/bar/baz
    func resolve(_ other: RelativeURL) -> Self? {
        guard let url = URL(string: other.string, relativeTo: url) else {
            return nil
        }
        return Self(url: url)
    }

    /// Relativizes the `other` URL against this base URL, if possible.
    ///
    /// For example:
    ///     self: http://example.com/foo
    ///     other: http://example.com/foo/bar/baz
    ///     returns bar/baz
    func relativize<T: URLConvertible>(_ other: T) -> RelativeURL? {
        guard
            let absoluteURL = other.anyURL.absoluteURL,
            scheme == absoluteURL.scheme,
            origin == absoluteURL.origin
        else {
            return nil
        }

        return RelativeURL(
            string: absoluteURL.string
                .removingPrefix(string)
                .removingPrefix("/")
        )
    }

    /// Indicates whether the receiver is relative to the given `base` URL.
    func isRelative<T: URLConvertible>(to base: T) -> Bool {
        base.anyURL.absoluteURL?.scheme == scheme
            && base.anyURL.absoluteURL?.origin == origin
    }
}

/// Implements ``URLConvertible``.
public extension AbsoluteURL {
    var anyURL: AnyURL { .absolute(self) }
}

/// A URL scheme, e.g. http or file.
public struct URLScheme: RawRepresentable, CustomStringConvertible, Hashable, Sendable {
    public static let data = URLScheme(rawValue: "data")
    public static let file = URLScheme(rawValue: "file")
    public static let ftp = URLScheme(rawValue: "ftp")
    public static let http = URLScheme(rawValue: "http")
    public static let https = URLScheme(rawValue: "https")
    public static let opds = URLScheme(rawValue: "opds")

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }

    public var description: String { rawValue }
}
