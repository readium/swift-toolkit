//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a relative URL.
public struct RelativeURL: URLProtocol, Hashable {

    public let url: URL

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

    /// Resolves the given `url` to this URL, if possible.
    ///
    /// For example:
    ///     self: foo/bar
    ///     other: baz
    ///     returns foo/baz
    public func resolve<T : URLConvertible>(_ other: T) -> AnyURL? {
        // other is absolute?
        guard let relativeURL = other.relativeURL else {
            return other.anyURL
        }
        return resolve(relativeURL)?.anyURL
    }

    /// Resolves the given `url` to this URL, if possible.
    ///
    /// For example:
    ///     self: foo/bar
    ///     other: baz
    ///     returns foo/baz
    public func resolve(_ other: RelativeURL) -> RelativeURL? {
        guard let url = URL(string: other.string, relativeTo: url) else {
            return nil
        }

        return RelativeURL(string: url.absoluteString.removingPrefix("//"))
    }

    /// Resolves the given absolute `url` to this URL.
    ///
    /// As the receiver is relative, the given absolute URL is returned.
    public func resolve(_ other: AbsoluteURL) -> AbsoluteURL? {
        other
    }

    /// Relativizes the given `url` against this relative URL, if possible.
    ///
    /// For example:
    ///     self: foo/bar
    ///     other: foo/bar/baz
    ///     returns baz
    public func relativize<T : URLConvertible>(_ other: T) -> RelativeURL? {
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
}
