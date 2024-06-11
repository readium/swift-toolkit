//
//  Copyright 2024 Readium Foundation. All rights reserved.
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

    public func hash(into hasher: inout Hasher) {
        hasher.combine(scheme)
        hasher.combine(host)
        hasher.combine(url.port)
        hasher.combine(path)
        hasher.combine(query)
        hasher.combine(fragment)
        hasher.combine(url.user)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.scheme == rhs.scheme
            && lhs.host == rhs.host
            && lhs.url.port == rhs.url.port
            && lhs.path == rhs.path
            && lhs.query == rhs.query
            && lhs.fragment == rhs.fragment
            && lhs.url.user == rhs.url.user
    }
}
