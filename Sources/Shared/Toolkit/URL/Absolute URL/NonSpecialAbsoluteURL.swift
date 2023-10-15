//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

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
