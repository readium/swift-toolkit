//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Creates ``HTTPResource`` instances granting access to `http(s)://` URLs
/// using an ``HTTPClient``.
public final class HTTPResourceFactory: ResourceFactory {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func make(url: any AbsoluteURL) async throws(ResourceMakeError) -> any Resource {
        guard let url = url.httpURL else {
            throw .schemeNotSupported(url.scheme)
        }
        return HTTPResource(url: url, client: client)
    }
}
