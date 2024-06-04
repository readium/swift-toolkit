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

    public let links: [Link] = []

    public func get(_ link: Link) -> Resource {
        guard let url = try? link.url(relativeTo: baseURL).httpURL else {
            log(.error, "Not a valid HTTP URL: \(link.href)")
            return FailureResource(link: link, error: .badRequest(HTTPError(kind: .malformedRequest(url: link.href))))
        }
        return HTTPResource(client: client, link: link, url: url)
    }

    public func close() {}

}

private extension HTTPClient {
    // FIXME: Get rid of this hack.
    func fetchWait(_ request: HTTPRequestConvertible) -> HTTPResult<HTTPResponse> {
        warnIfMainThread()

        let enclosure = Enclosure()
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            enclosure.value = await fetch(request)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)

        return enclosure.value
    }
}

class Enclosure {
    var value: HTTPResult<HTTPResponse>!
}
