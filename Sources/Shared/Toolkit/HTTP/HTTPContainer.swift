//
//  Copyright 2025 Readium Foundation. All rights reserved.
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

    public init(
        client: HTTPClient,
        baseURL: HTTPURL? = nil,
        entries: Set<AnyURL> = []
    ) {
        self.client = client
        self.baseURL = baseURL
        self.entries = entries
    }

    public let sourceURL: AbsoluteURL? = nil
    public let entries: Set<AnyURL>

    public subscript(url: any URLConvertible) -> (any Resource)? {
        // We don't check that url matches any entry because that might save us
        // from edge cases.
        guard let url = baseURL?.resolve(url)?.httpURL ?? url.httpURL else {
            return nil
        }
        return HTTPResource(url: url, client: client)
    }
}
