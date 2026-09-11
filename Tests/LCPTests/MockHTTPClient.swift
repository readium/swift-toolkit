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
    @Atomic private var _requestCount = 0

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
        _requestCount
    }

    func stream(
        request: HTTPRequestConvertible,
        consume: @escaping (Data, Double?) -> HTTPResult<Void>
    ) async -> HTTPResult<HTTPResponse> {
        let httpRequest: HTTPRequest
        switch request.httpRequest() {
        case let .success(request):
            httpRequest = request
        case let .failure(error):
            return .failure(error)
        }
        $_requestCount.write { $0 += 1 }

        let response = HTTPResponse(
            request: httpRequest,
            url: httpRequest.url,
            status: status,
            headers: [:],
            mediaType: mediaType,
            body: nil
        )
        responsesStream.continuation.yield(response)

        if case let .failure(error) = consume(body, 1.0) {
            return .failure(error)
        }

        return .success(response)
    }
}
