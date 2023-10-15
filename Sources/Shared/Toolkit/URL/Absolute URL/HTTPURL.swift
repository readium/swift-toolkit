//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

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
