//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Fetches remote resources with HTTP.
public final class HTTPContainer: Container {
    /// HTTP client used to perform HTTP requests.
    private let client: HTTPClient

    /// Base URL from which relative HREF are served.
    private let baseURL: HTTPURL?

    public init(client: HTTPClient, baseURL: HTTPURL? = nil) {
        self.client = client
        self.baseURL = baseURL
    }

    public var entries: Set<AnyURL> { Set() }

    public subscript(url: any URLConvertible) -> (any Resource)? {
        guard let url = baseURL?.resolve(url)?.httpURL ?? url.httpURL else {
            return nil
        }
        return HTTPResource(url: url, client: client)
    }
}
