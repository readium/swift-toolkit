//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Fetches remote resources with HTTP.
public final class HTTPFetcher: Fetcher, Loggable {
    
    /// HTTP client used to perform HTTP requests.
    private let client: HTTPClient
    /// Base URL from which relative HREF are served.
    private let baseURL: URL?

    public init(client: HTTPClient, baseURL: URL? = nil) {
        self.client = client
        self.baseURL = baseURL
    }
    
    public let links: [Link] = []
    
    public func get(_ link: Link) -> Resource {
        guard
            let url = link.url(relativeTo: baseURL),
            url.isHTTP
        else {
            log(.error, "Not a valid HTTP URL: \(link.href)")
            return FailureResource(link: link, error: .badRequest(HTTPError(kind: .malformedRequest(url: link.href))))
        }
        return HTTPResource(client: client, link: link, url: url)
    }
    
    public func close() { }

    /// HTTPResource provides access to an external URL.
    final class HTTPResource: NSObject, Resource, Loggable, URLSessionDataDelegate {

        let link: Link
        let url: URL

        private let client: HTTPClient

        init(client: HTTPClient, link: Link, url: URL) {
            self.client = client
            self.link = link
            self.url = url
        }

        var length: ResourceResult<UInt64> {
            headResponse.flatMap {
                if let length = $0.contentLength {
                    return .success(UInt64(length))
                } else {
                    return .failure(.unavailable(nil))
                }
            }
        }

        /// Cached HEAD response to get the expected content length and other metadata.
        private lazy var headResponse: ResourceResult<HTTPResponse> = {
            return client.fetchSync(HTTPRequest(url: url, method: .head))
                .mapError { ResourceError.wrap($0) }
        }()

        /// An HTTP resource is always remote.
        var file: URL? { nil }

        func stream(range: Range<UInt64>?, consume: @escaping (Data) -> (), completion: @escaping (ResourceResult<()>) -> ()) -> Cancellable {
            var request = HTTPRequest(url: url)
            if let range = range {
                request.setRange(range)
            }

            return client.stream(request,
                receiveResponse: nil,
                consume: { data, _ in consume(data) },
                completion: { result in
                    completion(result.map { _ in }.mapError { ResourceError.wrap($0) })
                }
            )
        }

        func close() {}

    }

}
