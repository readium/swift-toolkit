//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// An `HTTPClient` returning a canned response to every request.
final class MockHTTPClient: HTTPClient {
    private let body: Data
    private let status: HTTPStatus
    private let mediaType: MediaType?

    private let responsesStream = AsyncStream.makeStream(of: HTTPResponse.self)
    private let _requestCount = Mutex(0)

    init(body: Data, status: HTTPStatus = .ok, mediaType: MediaType? = nil) {
        self.body = body
        self.status = status
        self.mediaType = mediaType
    }

    /// Yields each response returned, to await a request made in the
    /// background.
    var responses: AsyncStream<HTTPResponse> {
        responsesStream.stream
    }

    /// Number of requests received.
    var requestCount: Int {
        _requestCount.withLock { $0 }
    }

    func stream(
        _ request: any HTTPRequestConvertible,
        onReceiveResponse: (@Sendable (HTTPResponse) async -> HTTPResult<Void>)?,
        consume: @Sendable (Data, Double?) -> HTTPResult<Void>
    ) async -> HTTPResult<HTTPResponse> {
        guard let request = try? request.httpRequest().get() else {
            return .failure(.malformedResponse(nil))
        }
        _requestCount.withLock { $0 += 1 }

        let response = HTTPResponse(
            request: request,
            url: request.url,
            status: status,
            headers: [:],
            mediaType: mediaType
        )
        _ = await onReceiveResponse?(response)
        _ = consume(body, 1.0)
        responsesStream.continuation.yield(response)

        return .success(response)
    }
}
