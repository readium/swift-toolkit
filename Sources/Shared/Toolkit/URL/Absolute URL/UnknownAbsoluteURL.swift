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
}
