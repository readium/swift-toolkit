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

    class MockHTTPClient: HTTPClient {
        struct Response {
            let response: HTTPResponse
            let body: Data
        }

        var fetchResults: [String: HTTPResult<Response>] = [:]
        var fetchCount = 0

        func stream(
            _ request: HTTPRequestConvertible,
            onReceiveResponse: ((HTTPResponse) async -> HTTPResult<Void>)?,
            consume: (Data, Double?) -> HTTPResult<Void>
        ) async -> HTTPResult<HTTPResponse> {
            let req = try! request.httpRequest().get()
            let key = "\(req.method.rawValue) \(req.url.string)"
            fetchCount += 1

            if let result = fetchResults[key] {
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

        var streamedData = Data()
        let result = await resource.stream(range: 0 ..< 10, consume: { streamedData.append($0) })

        try result.get()
        #expect(streamedData == "0123456789".data(using: .utf8))
    }
}
