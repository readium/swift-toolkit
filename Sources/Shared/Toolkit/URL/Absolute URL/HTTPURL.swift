//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents an absolute URL with the special schemes `http` or `https`.
///
/// See https://url.spec.whatwg.org/#special-scheme
public struct HTTPURL: AbsoluteURL, Hashable, Sendable {
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

    /// Strict URL comparisons can be a source of bug, if the URLs are not
    /// normalized. In most cases, you should compare using
    /// `isEquivalent()`.
    ///
    /// To ignore this warning, compare `HTTPURL.string` instead of
    /// `HTTPURL` itself.
    @available(*, deprecated, message: "Strict URL comparisons can be a source of bug. Use isEquivalent() instead.")
    public static func == (lhs: HTTPURL, rhs: HTTPURL) -> Bool {
        lhs.string == rhs.string
    }
}

public extension URLConvertible {
    /// Returns an `HTTPURL` if the URL has an `http` or `https` scheme.
    var httpURL: HTTPURL? {
        (anyURL.absoluteURL as? HTTPURL) ?? HTTPURL(url: anyURL.url)
    }
}
