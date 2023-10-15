//
//  Copyright 2023 Readium Foundation. All rights reserved.
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

    /// Resolves the given `url` to this URL, if possible.
    ///
    /// For example:
    ///     self: http://example.com/foo/
    ///     other: bar/baz
    ///     returns http://example.com/foo/bar/baz
    func resolve<T: URLConvertible>(_ other: T) -> Self?

    /// Relativizes the given `url` against this base URL, if possible.
    ///
    /// For example:
    ///     self: http://example.com/foo
    ///     other: http://example.com/foo/bar/baz
    ///     returns bar/baz
    func relativize<T: URLConvertible>(_ other: T) -> RelativeURL?

    /// Indicates whether the receiver is relative to the given `base` URL.
    func isRelative<T: URLConvertible>(to base: T) -> Bool
}

public extension AbsoluteURL {
    func resolve<T: URLConvertible>(_ other: T) -> Self? {
        guard let relativeURL = other.relativeURL else {
            return nil
        }

        guard let url = URL(string: relativeURL.string, relativeTo: url) else {
            return nil
        }
        return Self(url: url)
    }

    func relativize<T: URLConvertible>(_ other: T) -> RelativeURL? {
        guard
            let absoluteURL = other.absoluteURL,
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

    func isRelative<T: URLConvertible>(to base: T) -> Bool {
        base.absoluteURL?.scheme == scheme
            && base.absoluteURL?.origin == origin
    }
}

/// Implements `URLConvertible`.
public extension AbsoluteURL {
    var anyURL: AnyURL { .absolute(self) }
    var relativeURL: RelativeURL? { nil }
    var absoluteURL: AbsoluteURL? { self }
}

/// A URL scheme, e.g. http or file.
public struct URLScheme: RawRepresentable, CustomStringConvertible, Hashable {
    public static let file = URLScheme(rawValue: "file")
    public static let ftp = URLScheme(rawValue: "ftp")
    public static let http = URLScheme(rawValue: "http")
    public static let https = URLScheme(rawValue: "https")

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }

    public var description: String { rawValue }
}
