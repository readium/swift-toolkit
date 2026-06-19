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

        client.fetchResults["HEAD \(url.string)"] = .success(.init(
            response: HTTPResponse(
                request: HTTPRequest(url: url, method: .head),
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
        client.fetchResults["HEAD \(url.string)"] = .failure(.errorResponse(response))
        client.fetchResults["GET \(url.string)"] = .failure(.errorResponse(response))

        let length = await resource.estimatedLength()
        try #expect(length.get() == nil)
        #expect(client.fetchCount == 2)
    }

    @Test func headResponseFallbackToRangeRequestSucceeds() async throws {
        let client = MockHTTPClient()
        let resource = HTTPResource(url: url, client: client)

        client.fetchResults["HEAD \(url.string)"] = .failure(.errorResponse(HTTPErrorResponse(status: .methodNotAllowed)))
        client.fetchResults["GET \(url.string)"] = .success(.init(
            response: HTTPResponse(
                request: HTTPRequest(url: url),
                url: url,
                status: .partialContent,
                headers: ["Content-Range": "bytes 0-1/512"],
                mediaType: .epub
            ),
            body: Data()
        ))

        let length = await resource.estimatedLength()
        try #expect(length.get() == 512)
        #expect(client.fetchCount == 2)
    }

    @Test func propertiesMediaTypeFromHeadResponse() async throws {
        let client = MockHTTPClient()
        let resource = HTTPResource(url: url, client: client)

        client.fetchResults["HEAD \(url.string)"] = .success(.init(
            response: HTTPResponse(
                request: HTTPRequest(url: url, method: .head),
                url: url,
                status: .ok,
                headers: [:],
                mediaType: .epub
            ),
            body: Data()
        ))

        let props = try await resource.properties().get()
        #expect(props.mediaType == .epub)
        #expect(props.filename == "book.epub")
    }

    @Test func propertiesFilenameFromContentDisposition() async throws {
        let client = MockHTTPClient()
        let resource = HTTPResource(url: url, client: client)

        client.fetchResults["HEAD \(url.string)"] = .success(.init(
            response: HTTPResponse(
                request: HTTPRequest(url: url, method: .head),
                url: url,
                status: .ok,
                headers: ["Content-Disposition": "attachment; filename=\"moby-dick.epub\""],
                mediaType: .epub
            ),
            body: Data()
        ))

        let props = try await resource.properties().get()
        #expect(props.filename == "moby-dick.epub")
    }

    @Test func streamWithRange() async throws {
        let client = MockHTTPClient()
        let resource = HTTPResource(url: url, client: client)

        client.fetchResults["HEAD \(url.string)"] = .success(.init(
            response: HTTPResponse(
                request: HTTPRequest(url: url, method: .head),
                url: url,
                status: .ok,
                headers: ["Content-Length": "100"],
                mediaType: .epub
            ),
            body: Data()
        ))

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

    @Test func estimatedLengthFromContentRange() async throws {
        let client = MockHTTPClient()
        let resource = HTTPResource(url: url, client: client)

        client.fetchResults["HEAD \(url.string)"] = .success(.init(
            response: HTTPResponse(
                request: HTTPRequest(url: url, method: .head),
                url: url,
                status: .partialContent,
                headers: ["Content-Range": "bytes 0-1/1000"],
                mediaType: .epub
            ),
            body: Data()
        ))

        let length = await resource.estimatedLength()
        try #expect(length.get() == 1000)
    }

    @Test func estimatedLengthUnknownWhenContentRangeSizeIsWildcard() async throws {
        let client = MockHTTPClient()
        let resource = HTTPResource(url: url, client: client)

        client.fetchResults["HEAD \(url.string)"] = .success(.init(
            response: HTTPResponse(
                request: HTTPRequest(url: url, method: .head),
                url: url,
                status: .partialContent,
                headers: [
                    "Content-Range": "bytes 0-1/*",
                    "Content-Length": "2",
                ],
                mediaType: .epub
            ),
            body: Data()
        ))

        let length = await resource.estimatedLength()
        try #expect(length.get() == nil)
    }

    @Test func estimatedLengthFromContentLength() async throws {
        let client = MockHTTPClient()
        let resource = HTTPResource(url: url, client: client)

        client.fetchResults["HEAD \(url.string)"] = .success(.init(
            response: HTTPResponse(
                request: HTTPRequest(url: url, method: .head),
                url: url,
                status: .ok,
                headers: ["Content-Length": "2048"],
                mediaType: .epub
            ),
            body: Data()
        ))

        let length = await resource.estimatedLength()
        try #expect(length.get() == 2048)
    }
}
