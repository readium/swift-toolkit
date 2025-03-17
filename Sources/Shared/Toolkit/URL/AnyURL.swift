//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Represents either an absolute or relative URL.
///
/// See https://url.spec.whatwg.org
public enum AnyURL: URLProtocol {
    /// An absolute URL.
    case absolute(AbsoluteURL)

    /// A relative URL.
    case relative(RelativeURL)

    /// Creates an ``AnyURL`` from a Foundation ``URL``.
    public init(url: URL) {
        if let url = RelativeURL(url: url) {
            self = .relative(url)
        } else if let url = HTTPURL(url: url) {
            self = .absolute(url)
        } else if let url = FileURL(url: url) {
            self = .absolute(url)
        } else if let url = UnknownAbsoluteURL(url: url) {
            self = .absolute(url)
        } else {
            fatalError("URL is not absolute nor relative: \(url)")
        }
    }

    /// Creates an ``AnyURL`` from a decoded relative `path`.
    public init?(path: String) {
        guard let url = RelativeURL(path: path) else {
            return nil
        }
        self = .relative(url)
    }

    /// Creates an `AnyURL` from a legacy HREF.
    ///
    /// For example, if it is a relative path such as `/dir/my chapter.html`,
    /// it will be / converted to the valid relative URL `dir/my%20chapter.html`.
    ///
    /// Only use this API when you are upgrading to Readium 3.x and migrating
    /// the HREFs stored in / your database. See the 3.0 migration guide for
    /// more information.
    public init?(legacyHREF href: String) {
        if let url = URL(string: href), url.scheme != nil {
            self.init(url: url)
        } else if let url = RelativeURL(path: href.removingPrefix("/")) {
            self = .relative(url)
        } else {
            return nil
        }
    }

    /// Returns the wrapped ``RelativeURL``, if this URL is relative.
    public var relativeURL: RelativeURL? {
        guard case let .relative(url) = self else {
            return nil
        }
        return url
    }

    /// Returns the wrapped ``AbsoluteURL``, if this URL is absolute.
    public var absoluteURL: AbsoluteURL? {
        guard case let .absolute(url) = self else {
            return nil
        }
        return url
    }

    private var wrapped: URLProtocol {
        switch self {
        case let .absolute(url):
            return url
        case let .relative(url):
            return url
        }
    }

    /// Returns a foundation URL for this ``AnyURL``.
    public var url: URL { wrapped.url }

    /// Resolves the `other` URL to this URL, if possible.
    ///
    /// For example:
    ///     self: http://example.com/foo/
    ///     other: bar/baz
    ///     returns http://example.com/foo/bar/baz
    public func resolve<T: URLConvertible>(_ other: T) -> AnyURL? {
        switch self {
        case let .absolute(url):
            return url.resolve(other).map { .absolute($0) }
        case let .relative(url):
            return url.resolve(other)?.anyURL
        }
    }

    /// Relativizes the `other` URL against this base URL, if possible.
    ///
    /// For example:
    ///     self: http://example.com/foo
    ///     other: http://example.com/foo/bar/baz
    ///     returns bar/baz
    public func relativize<T: URLConvertible>(_ other: T) -> AnyURL? {
        switch self {
        case let .absolute(url):
            return url.relativize(other)?.anyURL
        case let .relative(url):
            return url.relativize(other)?.anyURL
        }
    }
}

/// Implements `URLConvertible`.
extension AnyURL: URLConvertible {
    public var anyURL: AnyURL { self }
}

/// Implements `Hashable` and `Equatable`.
extension AnyURL: Hashable {
    /// Strict URL comparisons can be a source of bug, if the URLs are not
    /// normalized. In most cases, you should compare using
    /// `isEquivalent()`.
    ///
    /// To ignore this warning, compare `AnyURL.string` instead of
    /// `AnyURL` itself.
    @available(*, deprecated, message: "Strict URL comparisons can be a source of bug. Use isEquivalent() instead.")
    public static func == (lhs: AnyURL, rhs: AnyURL) -> Bool {
        lhs.string == rhs.string
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(string)
    }

    public var hashValue: Int {
        string.hashValue
    }
}
