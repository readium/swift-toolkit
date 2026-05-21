//
//  Copyright 2026 Readium Foundation. All rights reserved.
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

    public nonisolated var sourceURL: AbsoluteURL? {
        url
    }

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
    private func setHeadResponse(_ result: ReadResult<HTTPResponse?>) {
        _headResponse = result
    }

    /// Cached HEAD response to get the expected content length and other
    /// metadata.
    ///
    /// For compatibility reason, we start a byte range request of 2 bytes and
    /// interrupt it right away.
    private func headResponse() async -> ReadResult<HTTPResponse?> {
        if _headResponse == nil {
            var request = HTTPRequest(url: url)
            request.setRange(0 ..< 2)

            let result = await client.stream(
                request,
                onReceiveResponse: { response in
                    await self.setHeadResponse(.success(response))
                    return .failure(.cancelled)
                },
                consume: { _, _ in .failure(.cancelled) }
            )

            if _headResponse == nil, case let .failure(error) = result {
                if let error: ReadError = .wrap(error) {
                    _headResponse = .failure(error)
                } else {
                    _headResponse = .success(nil)
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
            request,
            consume: { data, _ in
                consume(data)
                return .success(())
            }
        )
        .map { _ in () }
        .mapError { .access(.http($0)) }
    }
}
