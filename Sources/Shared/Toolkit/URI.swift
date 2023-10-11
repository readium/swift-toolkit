//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Represents a Uniform Resource Identifier, such as a URL.
public enum URI: Hashable {
    case absoluteURL(AbsoluteURL)
    case relativeURL(RelativeURL)

    /// Creates a `URI` from its encoded string representation.
    public init?(string: String) {
        guard let url = URL(percentEncodedString: string) else {
            return nil
        }
        self.init(url: url)
    }

    /// Creates a `URI` from a standard Swift `URL`.
    public init?(url: URL) {
        if let url = AbsoluteURL(url: url) {
            self = .absoluteURL(url)
        } else if let url = RelativeURL(url: url) {
            self = .relativeURL(url)
        } else {
            return nil
        }
    }

    /// Creates a relative URL from a percent-decoded path.
    public init?(decodedPath: String) {
        guard let url = RelativeURL(decodedPath: decodedPath) else {
            return nil
        }
        self = .relativeURL(url)
    }

    /// Creates a `URI` from a legacy HREF.
    ///
    /// For example, if it is a relative path such as `/dir/my chapter.html`,
    /// it will be / converted to the valid relative URL `dir/my%20chapter.html`.
    ///
    /// Only use this API when you are upgrading to Readium 3.x and migrating
    /// the HREFs stored in / your database. See the 3.0 migration guide for
    /// more information.
    public init?(legacyHref href: String) {
        if let url = AbsoluteURL(string: href) {
            self = .absoluteURL(url)
        } else {
            self.init(decodedPath: href.removingPrefix("/"))
        }
    }

    public var url: _URLProtocol {
        switch self {
        case let .absoluteURL(uri):
            return uri
        case let .relativeURL(uri):
            return uri
        }
    }

    public var absoluteURL: AbsoluteURL? {
        switch self {
        case let .absoluteURL(url):
            return url
        default:
            return nil
        }
    }

    public var relativeURL: RelativeURL? {
        switch self {
        case let .relativeURL(url):
            return url
        default:
            return nil
        }
    }

    public var string: String { url.string }

    /// Resolves the given `uri` to this URI, if possible.
    ///
    /// For example:
    ///     this = "http://example.com/foo/"
    ///     url = "bar/baz"
    ///     result = "http://example.com/foo/bar/baz"
    func resolve(_ uri: URI) -> URI? {
        guard case .relativeURL = uri else {
            return uri
        }

        guard let url = URL(string: uri.string, relativeTo: url.url) else {
            return nil
        }

        if url.scheme == nil {
            return URI(string: url.absoluteString.removingPrefix("//"))
        } else {
            return URI(url: url)
        }
    }

    /// Relativizes the given `uri` against this base URI, if possible.
    ///
    /// For example:
    ///     this = "http://example.com/foo"
    ///     url = "http://example.com/foo/bar/baz"
    ///     result = "bar/baz"
    func relativize(_ uri: URI) -> URI? {
        URI(string: uri.string.removingPrefix(string.addingSuffix("/")).removingPrefix(string))
    }
}

/// Represents a relative Uniform Resource Locator.
public struct RelativeURL: _URLProtocol, Hashable {
    public let url: URL

    public var string: String { url.absoluteString }

    /// Creates a `RelativeURL` from its encoded string representation.
    public init?(string: String) {
        guard let url = URL(percentEncodedString: string) else {
            return nil
        }
        self.init(url: url)
    }

    /// Creates a `RelativeURL` from a standard Swift `URL`.
    public init?(url: URL) {
        guard url.scheme == nil else {
            return nil
        }

        self.url = url.absoluteURL
    }

    /// Creates a `RelativeURL` from a percent-decoded path.
    public init?(decodedPath: String) {
        guard let path = decodedPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }

        self.init(string: path)
    }
}

/// Represents an absolute Uniform Resource Locator.
public struct AbsoluteURL: _URLProtocol, Hashable {
    public let url: URL

    /// Identifies the type of URL.
    public let scheme: URLScheme

    /// Indicates whether this URL points to a HTTP resource.
    public var isHTTP: Bool { scheme == .http || scheme == .https }

    /// Indicates whether this URL points to a file.
    public var isFile: Bool { scheme == .file }

    public var string: String { url.absoluteString }

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

/// Represents a list of query parameters in a URL.
public struct URLQuery {
    public let parameters: [URLQueryParameter]

    public init(parameters: [URLQueryParameter] = []) {
        self.parameters = parameters
    }

    /// Returns the first value for the parameter with the given `name`.
    public func first(named name: String) -> String? {
        parameters.first(where: { $0.name == name })?.value
    }

    /// Returns all the values for the parameter with the given `name`.
    public func all(named name: String) -> [String] {
        parameters.filter { $0.name == name }.compactMap(\.value)
    }
}

/// Represents a single query parameter and its value in a URL.
public struct URLQueryParameter {
    public let name: String
    public let value: String?
}

private extension URL {
    init?(percentEncodedString: String) {
        if #available(iOS 17.0, *) {
            self.init(string: percentEncodedString, encodingInvalidCharacters: false)
        } else {
            self.init(string: percentEncodedString)
        }
    }
}

/// Internal protocol to simplify the implementation of `URI`.
/// Don't use it directly.
public protocol _URLProtocol {
    /// Returns the Swift `URL` representation for this URL.
    var url: URL { get }

    /// Returns the string representation for this URL.
    var string: String { get }

    /// Returns the decoded query parameters present in this URL, in the order
    /// they appear.
    var query: URLQuery { get }
}

public extension _URLProtocol {
    var query: URLQuery {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems else {
            return URLQuery()
        }

        return URLQuery(parameters: items.map {
            URLQueryParameter(name: $0.name, value: $0.value)
        })
    }
}
