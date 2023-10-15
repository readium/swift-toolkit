//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A type that can represent an absolute URL with a scheme.
public protocol AbsoluteURLProtocol: URLProtocol {
    /// Identifies the type of URL.
    var scheme: URLScheme { get }

    /// Origin of the URL.
    ///
    /// See https://url.spec.whatwg.org/#origin
    var origin: String? { get }
}

public extension AbsoluteURLProtocol {
    /// Resolves the given `url` to this URL, if possible.
    ///
    /// For example:
    ///     self: http://example.com/foo/
    ///     other: bar/baz
    ///     returns http://example.com/foo/bar/baz
    func resolve<T: URLConvertible>(_ other: T) -> Self? {
        guard let relativeURL = other.relativeURL else {
            return nil
        }

        guard let url = URL(string: relativeURL.string, relativeTo: url) else {
            return nil
        }
        return Self(url: url)
    }

    /// Relativizes the given `url` against this base URL, if possible.
    ///
    /// For example:
    ///     self: http://example.com/foo
    ///     other: http://example.com/foo/bar/baz
    ///     returns bar/baz
    func relativize<T: URLConvertible>(_ other: T) -> RelativeURL? {
        guard
            let absoluteURL = other.absoluteURL,
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
        base.absoluteURL?.origin == origin
    }
}

/// Represents any type of absolute URL.
public enum AnyAbsoluteURL: AbsoluteURLProtocol, Hashable {
    case http(HTTPURL)
    case file(FileURL)
    case other(NonSpecialAbsoluteURL)

    public init?(url: URL) {
        if let url = HTTPURL(url: url) {
            self = .http(url)
        } else if let url = FileURL(url: url) {
            self = .file(url)
        } else if let url = NonSpecialAbsoluteURL(url: url) {
            self = .other(url)
        } else {
            return nil
        }
    }

    private var wrapped: AbsoluteURLProtocol {
        switch self {
        case let .http(url):
            return url
        case let .file(url):
            return url
        case let .other(url):
            return url
        }
    }

    public var url: URL { wrapped.url }
    public var scheme: URLScheme { wrapped.scheme }
    public var origin: String? { wrapped.origin }

    public var httpURL: HTTPURL? { wrapped as? HTTPURL }
    public var fileURL: FileURL? { wrapped as? FileURL }
}

/// Represents an absolute URL with the special schemes `http` or `https`.
///
/// See https://url.spec.whatwg.org/#special-scheme
public struct HTTPURL: AbsoluteURLProtocol, Hashable {
    public init?(url: URL) {
        guard
            let scheme = url.scheme.map(URLScheme.init(rawValue:)),
            scheme == .http || scheme == .https
        else {
            return nil
        }

        self.scheme = scheme
        self.url = url.absoluteURL
    }

    public let url: URL
    public let scheme: URLScheme

    public var origin: String? {
        var o = "\(scheme)://"
        if let host = url.host {
            o += host
            if let port = url.port {
                o += ":\(port)"
            }
        }
        return o
    }
}

/// Represents an absolute URL with the special scheme `file`.
///
/// See https://url.spec.whatwg.org/#special-scheme
public struct FileURL: AbsoluteURLProtocol, Hashable {
    public init?(url: URL) {
        let url = url.standardizedFileURL
        guard
            let scheme = url.scheme.map(URLScheme.init(rawValue:)),
            scheme == .file,
            let path = url.path.orNilIfEmpty()
        else {
            return nil
        }

        self.path = path
        self.scheme = scheme
        self.url = url
    }

    public init?(path: String, isDirectory: Bool) {
        guard path.hasPrefix("/") else {
            return nil
        }
        self.init(url: URL(fileURLWithPath: path, isDirectory: isDirectory))
    }

    public let url: URL
    public let path: String
    public let scheme: URLScheme
    public let origin: String? = nil

    public var lastPathComponent: String { url.lastPathComponent }

    public var pathExtension: String { url.pathExtension }

    /// Returns whether the given `url` is `self` or one of its descendants.
    public func isParent(of other: FileURL) -> Bool {
        path == other.path || other.path.hasPrefix(path + "/")
    }

    /// Returns whether the file exists on the file system.
    public func exists() throws -> Bool {
        try url.checkResourceIsReachable()
    }

    /// Returns whether the file is a directory.
    public func isDirectory() -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
}

/// Represents an absolute URL with a scheme that is not special.
///
/// See https://url.spec.whatwg.org/#is-not-special
public struct NonSpecialAbsoluteURL: AbsoluteURLProtocol, Hashable {
    public init?(url: URL) {
        guard
            let scheme = url.scheme.map(URLScheme.init(rawValue:)),
            scheme != .file, scheme != .http, scheme != .https
        else {
            return nil
        }

        self.scheme = scheme
        self.url = url.absoluteURL
    }

    public let url: URL
    public let scheme: URLScheme
    public let origin: String? = nil
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
