//
//  Copyright 2025 Readium Foundation. All rights reserved.
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

    /// Strict URL comparisons can be a source of bug, if the URLs are not
    /// normalized. In most cases, you should compare using
    /// `isEquivalent()`.
    ///
    /// To ignore this warning, compare `RelativeURL.string` instead of
    /// `RelativeURL` itself.
    @available(*, deprecated, message: "Strict URL comparisons can be a source of bug. Use isEquivalent() instead.")
    public static func == (lhs: RelativeURL, rhs: RelativeURL) -> Bool {
        lhs.string == rhs.string
    }
}

/// Implements `URLConvertible`.
extension RelativeURL: URLConvertible {
    public var anyURL: AnyURL { .relative(self) }
    public var relativeURL: RelativeURL? { self }
    public var absoluteURL: AbsoluteURL? { nil }
}

public extension RelativeURL {
    /// According to the EPUB specification, the HREFs in the EPUB package must
    /// be valid URLs (so percent-encoded). Unfortunately, many EPUBs don't
    /// follow this rule, and use invalid HREFs such as `﻿my chapter.html`
    /// or ﻿`/dir/my chapter.html`.
    ///
    /// As a workaround, we assume the HREFs are valid percent-encoded URLs,
    /// and fallback to decoded paths if we can't parse the URL.
    init?(epubHREF: String) {
        guard let uri = RelativeURL(string: epubHREF) ?? RelativeURL(path: epubHREF) else {
            return nil
        }
        self = uri
    }
}
