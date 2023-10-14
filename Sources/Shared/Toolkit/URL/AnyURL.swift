//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Represents either an absolute or relative URL.
///
/// See https://url.spec.whatwg.org
public enum AnyURL: URLProtocol, Hashable {
    
    /// An absolute URL.
    case absolute(AbsoluteURL)
    
    /// A relative URL.
    case relative(RelativeURL)

    /// Creates an `AnyURL` from its encoded string representation.
    public init?(string: String) {
        guard let url = URL(percentEncodedString: string) else {
            return nil
        }
        self.init(url: url)
    }

    /// Creates an `AnyURL` from a Foundation `URL`.
    public init(url: URL) {
        if let url = AbsoluteURL(url: url) {
            self.init(url)
        } else if let url = RelativeURL(url: url) {
            self.init(url)
        } else {
            fatalError("URL is not absolute nor relative: \(url)")
        }
    }

    /// Creates a relative URL from a percent-decoded path.
    public init?(decodedPath: String) {
        guard let url = RelativeURL(decodedPath: decodedPath) else {
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
    public init?(legacyHref href: String) {
        if let url = AbsoluteURL(string: href) {
            self.init(url)
        } else {
            self.init(decodedPath: href.removingPrefix("/"))
        }
    }
    
    /// Wraps an `AbsoluteURL`.
    public init(_ url: AbsoluteURL) {
        self = .absolute(url)
    }
    
    /// Wraps a `RelativeURL`.
    public init(_ url: RelativeURL) {
        self = .relative(url)
    }

    private var wrapped: URLProtocol {
        switch self {
        case let .absolute(url):
            return url
        case let .relative(url):
            return url
        }
    }

    /// Returns a foundation URL for this `AnyURL`.
    public var url: URL { wrapped.url }

    /// Resolves the given `url` to this URL, if possible.
    ///
    /// For example:
    ///     self: http://example.com/foo/
    ///     other: bar/baz
    ///     returns http://example.com/foo/bar/baz
    public func resolve<T : URLConvertible>(_ other: T) -> AnyURL? {
        switch self {
        case let .absolute(url):
            return url.resolve(other)?.anyURL
        case let .relative(url):
            return url.resolve(other)?.anyURL
        }
    }

    /// Relativizes the given `uri` against this base URI, if possible.
    ///
    /// For example:
    ///     self: http://example.com/foo
    ///     other: http://example.com/foo/bar/baz
    ///     returns bar/baz
    public func relativize<T : URLConvertible>(_ other: T) -> AnyURL? {
        switch self {
        case let .absolute(url):
            return url.relativize(other)?.anyURL
        case let .relative(url):
            return url.relativize(other)?.anyURL
        }
    }
}
