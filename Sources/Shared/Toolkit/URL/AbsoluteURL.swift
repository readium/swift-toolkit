//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents an absolute URL.
public struct AbsoluteURL: URLProtocol, Hashable {
    
    /// Foundation URL.
    public let url: URL

    /// Identifies the type of URL.
    public let scheme: URLScheme

    /// Indicates whether this URL points to an HTTP resource.
    public var isHTTP: Bool { scheme == .http || scheme == .https }

    /// Indicates whether this URL points to a file.
    public var isFile: Bool { scheme == .file }

    /// Creates an `AbsoluteURL` from its encoded string representation.
    public init?(string: String) {
        guard let url = URL(percentEncodedString: string) else {
            return nil
        }
        self.init(url: url)
    }

    /// Creates an `AbsoluteURL` from a standard Swift `URL`.
    public init?(url: URL) {
        guard let scheme = url.scheme else {
            return nil
        }

        self.scheme = URLScheme(rawValue: scheme)
        self.url = url.absoluteURL
    }

    /// Resolves the given `url` to this URL, if possible.
    ///
    /// For example:
    ///     self: http://example.com/foo/
    ///     other: bar/baz
    ///     returns http://example.com/foo/bar/baz
    public func resolve<T : URLConvertible>(_ other: T) -> AbsoluteURL? {
        // other is absolute?
        guard let relativeURL = other.relativeURL else {
            return other.absoluteURL
        }

        guard let url = URL(string: relativeURL.string, relativeTo: url) else {
            return nil
        }
        return AbsoluteURL(url: url)
    }

    /// Indicates whether the receiver is relative to the given `base` URL.
    public func isRelative<T : URLConvertible>(to base: T) -> Bool {
        base.absoluteURL?.url.origin == url.origin
    }

    /// Relativizes the given `url` against this base URL, if possible.
    ///
    /// For example:
    ///     self: http://example.com/foo
    ///     other: http://example.com/foo/bar/baz
    ///     returns bar/baz
    public func relativize<T : URLConvertible>(_ other: T) -> RelativeURL? {
        guard
            let absoluteURL = other.absoluteURL,
            url.origin == absoluteURL.url.origin
        else {
            return nil
        }

        return RelativeURL(
            string: absoluteURL.string
                .removingPrefix(string)
                .removingPrefix("/")
        )
    }
}

/// A URL scheme, e.g. http or file.
public struct URLScheme: RawRepresentable, Hashable {
    public static let file = URLScheme(rawValue: "file")
    public static let http = URLScheme(rawValue: "http")
    public static let https = URLScheme(rawValue: "https")

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }
}
