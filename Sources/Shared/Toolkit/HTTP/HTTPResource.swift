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
        await headResponse().flatMap { response in
            if let length = response?.resourceLength {
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
    /// To ensure compatibility with servers that do not support HEAD requests,
    /// we fall back on a 2-byte range request and interrupt it immediately.
    private func headResponse() async -> ReadResult<HTTPResponse?> {
        if _headResponse == nil {
            let headRequest = HTTPRequest(url: url, method: .head)
            let _ = await client.stream(
                headRequest,
                onReceiveResponse: { response in
                    await self.setHeadResponse(.success(response))
                    return .success(())
                },
                consume: { _, _ in .success(()) }
            )

            if _headResponse == nil {
                var rangeRequest = HTTPRequest(url: url)
                rangeRequest.setRange(0 ..< 2)

                let rangeResult = await client.stream(
                    rangeRequest,
                    onReceiveResponse: { response in
                        await self.setHeadResponse(.success(response))
                        return .failure(.cancelled)
                    },
                    consume: { _, _ in .failure(.cancelled) }
                )

                if _headResponse == nil, case let .failure(error) = rangeResult {
                    if let error: ReadError = .wrap(error) {
                        _headResponse = .failure(error)
                    } else {
                        _headResponse = .success(nil)
                    }
                }
            }
        }
        return _headResponse!
    }

    public func stream(range: Range<UInt64>?, consume: @escaping @Sendable (Data) -> Void) async -> ReadResult<Void> {
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
