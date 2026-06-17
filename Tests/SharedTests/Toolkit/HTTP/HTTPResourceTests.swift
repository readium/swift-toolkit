//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

struct HTTPResourceTests {
    private let url = HTTPURL(string: "http://example.com/book.epub")!

    final class MockHTTPClient: HTTPClient {
        struct Response: Sendable {
            let response: HTTPResponse
            let body: Data
        }

        private let _fetchResults = Mutex<[String: HTTPResult<Response>]>([:])
        var fetchResults: [String: HTTPResult<Response>] {
            get { _fetchResults.withLock { $0 } }
            set { _fetchResults.withLock { $0 = newValue } }
        }

        private let _fetchCount = Mutex<Int>(0)
        var fetchCount: Int {
            _fetchCount.withLock { $0 }
        }

        func stream(
            _ request: any HTTPRequestConvertible,
            onReceiveResponse: (@Sendable (HTTPResponse) async -> HTTPResult<Void>)?,
            consume: @Sendable (Data, Double?) -> HTTPResult<Void>
        ) async -> HTTPResult<HTTPResponse> {
            let req = try! request.httpRequest().get()
            let key = "\(req.method.rawValue) \(req.url.string)"
            _fetchCount.withLock { $0 += 1 }

            if let result = _fetchResults.withLock({ $0[key] }) {
                switch result {
                case let .success(response):
                    if let onReceiveResponse = onReceiveResponse {
                        let _ = await onReceiveResponse(response.response)
                    }
                    _ = consume(response.body, 1.0)
                    return .success(response.response)
                case let .failure(error):
                    return .failure(error)
                }
            }
            return .failure(.cancelled)
        }
    }

    @Test func headResponseIsCached() async throws {
        let client = MockHTTPClient()
        let resource = HTTPResource(url: url, client: client)

        client.fetchResults["GET \(url.string)"] = .success(.init(
            response: HTTPResponse(
                request: HTTPRequest(url: url),
                url: url,
                status: .ok,
                headers: ["Content-Length": "1024"],
                mediaType: .epub
            ),
            body: Data()
        ))

        let length1 = await resource.estimatedLength()
        try #expect(length1.get() == 1024)
        #expect(client.fetchCount == 1)

        let length2 = await resource.estimatedLength()
        try #expect(length2.get() == 1024)
        #expect(client.fetchCount == 1) // Should be cached
    }

    @Test func headResponseFallbackOnMethodNotAllowed() async throws {
        let client = MockHTTPClient()
        let resource = HTTPResource(url: url, client: client)

        let response = HTTPErrorResponse(status: .methodNotAllowed)
        client.fetchResults["GET \(url.string)"] = .failure(.errorResponse(response))

        let length = await resource.estimatedLength()
        try #expect(length.get() == nil)
        #expect(client.fetchCount == 1)
    }

    @Test func streamWithRange() async throws {
        let client = MockHTTPClient()
        let resource = HTTPResource(url: url, client: client)

        client.fetchResults["GET \(url.string)"] = try .success(.init(
            response: HTTPResponse(
                request: HTTPRequest(url: url),
                url: url,
                status: .partialContent,
                headers: ["Content-Range": "bytes 0-9/100"],
                mediaType: .epub
            ),
            body: #require("0123456789".data(using: .utf8))
        ))

        let streamedData = Capture(Data())
        let result = await resource.stream(range: 0 ..< 10, consume: { chunk in streamedData.value.append(chunk) })

        try result.get()
        #expect(streamedData.value == "0123456789".data(using: .utf8))
    }
}
