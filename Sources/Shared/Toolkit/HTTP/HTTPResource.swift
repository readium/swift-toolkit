//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// ``HTTPResource`` provides access to an external URL through HTTP.
public actor HTTPResource: Resource {
    public let url: HTTPURL

    private let client: HTTPClient

    init(url: HTTPURL, client: HTTPClient) {
        self.url = url
        self.client = client
    }

    public nonisolated var sourceURL: AbsoluteURL? { url }

    public func properties() async -> ReadResult<ResourceProperties> {
        await headResponse()
            .map { response in
                ResourceProperties {
                    if let response = response {
                        $0.filename = response.filename ?? url.lastPathSegment
                        $0.mediaType = response.mediaType
                    }
                }
            }
    }

    public func estimatedLength() async -> ReadResult<UInt64?> {
        await headResponse().flatMap {
            if let length = $0?.contentLength {
                return .success(UInt64(length))
            } else {
                return .success(nil)
            }
        }
    }

    private var _headResponse: ReadResult<HTTPResponse?>?

    /// Cached HEAD response to get the expected content length and other
    /// metadata.
    private func headResponse() async -> ReadResult<HTTPResponse?> {
        if _headResponse == nil {
            _headResponse = await client.fetch(HTTPRequest(url: url, method: .head))
                .map { $0 as HTTPResponse? }
                .flatMapError { error in
                    switch error {
                    case let .errorResponse(response) where response.status == .methodNotAllowed:
                        return .success(nil)
                    default:
                        return .failure(.access(.http(error)))
                    }
                }
        }
        return _headResponse!
    }

    public func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async -> ReadResult<Void> {
        let request = {
            var request = HTTPRequest(url: url)
            if let range = range {
                request.setRange(range)
            }
            return request
        }()

        return await client.stream(
            request: request,
            consume: { data, _ in
                consume(data)
                return .success(())
            }
        )
        .map { _ in () }
        .mapError { .access(.http($0)) }
    }
}
