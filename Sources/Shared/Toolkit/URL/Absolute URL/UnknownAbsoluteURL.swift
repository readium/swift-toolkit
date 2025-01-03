//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents an absolute URL with a scheme that is not known.
///
/// Kept private, it is the default `AbsoluteURL` implementation for schemes
/// that we don't know.
struct UnknownAbsoluteURL: AbsoluteURL, Hashable {
    init?(url: URL) {
        guard let scheme = url.scheme.map(URLScheme.init(rawValue:)) else {
            return nil
        }

        self.scheme = scheme
        self.url = url.absoluteURL
    }

    let url: URL
    let scheme: URLScheme
    let origin: String? = nil

    /// Strict URL comparisons can be a source of bug, if the URLs are not
    /// normalized. In most cases, you should compare using
    /// `isEquivalent()`.
    ///
    /// To ignore this warning, compare `UnknownAbsoluteURL.string` instead of
    /// `UnknownAbsoluteURL` itself.
    @available(*, deprecated, message: "Strict URL comparisons can be a source of bug. Use isEquivalent() instead.")
    public static func == (lhs: UnknownAbsoluteURL, rhs: UnknownAbsoluteURL) -> Bool {
        lhs.string == rhs.string
    }
}
