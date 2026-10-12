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
    private let client = MockHTTPClient()
    private let resource: HTTPResource

    init() {
        resource = HTTPResource(url: url, client: client)
    }

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
                    // The request is interrupted when the response is
                    // refused, as `DefaultHTTPClient` does.
                    if case let .failure(error) = await onReceiveResponse?(response.response) {
                        return .failure(error)
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
        respond(to: .head, headers: ["Content-Length": "1024"])

        let length1 = await resource.estimatedLength()
        try #expect(length1.get() == 1024)
        #expect(client.fetchCount == 1)

        let length2 = await resource.estimatedLength()
        try #expect(length2.get() == 1024)
        #expect(client.fetchCount == 1) // Should be cached
    }

    /// The server answered both requests without giving the length, which is
    /// then unknown for good.
    @Test(arguments: [
        HTTPError.errorResponse(HTTPErrorResponse(status: .methodNotAllowed)),
        .errorResponse(HTTPErrorResponse(status: .notFound)),
        .rangeNotSupported,
    ])
    func unknownLengthIsCachedWhenServerRefusesFallback(error: HTTPError) async throws {
        fail(.head, with: .errorResponse(HTTPErrorResponse(status: .methodNotAllowed)))
        fail(.get, with: error)

        let length1 = await resource.estimatedLength()
        try #expect(length1.get() == nil)
        #expect(client.fetchCount == 2)

        let length2 = await resource.estimatedLength()
        try #expect(length2.get() == nil)
        #expect(client.fetchCount == 2) // Should be cached
    }

    /// A request which was cancelled, or failed before the server answered,
    /// tells nothing about the resource.
    @Test(arguments: [
        (HTTPError.cancelled, ReadError.cancelled),
        (.offline(nil), .access(.http(.offline(nil)))),
    ])
    func failedRequestsAreReportedAndNotCached(error: HTTPError, expected: ReadError) async throws {
        fail(.head, with: error)
        fail(.get, with: error)

        #expect(await resource.estimatedLength() == .failure(expected))
        #expect(await resource.properties() == .failure(expected))

        // The next call asks the server again.
        respond(to: .head, headers: ["Content-Length": "1024"])

        let length = await resource.estimatedLength()
        try #expect(length.get() == 1024)
    }

    /// The HEAD request is refused by the server, or failed before it
    /// answered.
    @Test(arguments: [
        HTTPError.errorResponse(HTTPErrorResponse(status: .methodNotAllowed)),
        .offline(nil),
    ])
    func headResponseFallbackToRangeRequestSucceeds(headError: HTTPError) async throws {
        fail(.head, with: headError)
        respond(to: .get, status: .partialContent, headers: ["Content-Range": "bytes 0-1/512"])

        let length = await resource.estimatedLength()
        try #expect(length.get() == 512)
        #expect(client.fetchCount == 2)
    }

    @Test func propertiesMediaTypeFromHeadResponse() async throws {
        respond(to: .head)

        let props = try await resource.properties().get()
        #expect(props.mediaType == .epub)
        #expect(props.filename == "book.epub")
    }

    @Test func propertiesFilenameFromContentDisposition() async throws {
        respond(to: .head, headers: ["Content-Disposition": "attachment; filename=\"moby-dick.epub\""])

        let props = try await resource.properties().get()
        #expect(props.filename == "moby-dick.epub")
    }

    @Test func streamWithRange() async throws {
        respond(to: .head, headers: ["Content-Length": "100"])
        respond(
            to: .get,
            status: .partialContent,
            headers: ["Content-Range": "bytes 0-9/100"],
            body: Data("0123456789".utf8)
        )

        let streamedData = Capture(Data())
        let result = await resource.stream(range: 0 ..< 10, consume: { chunk in streamedData.value.append(chunk) })

        try result.get()
        #expect(streamedData.value == Data("0123456789".utf8))
    }

    @Test func estimatedLengthFromContentRange() async throws {
        respond(to: .head, status: .partialContent, headers: ["Content-Range": "bytes 0-1/1000"])

        let length = await resource.estimatedLength()
        try #expect(length.get() == 1000)
    }

    @Test func estimatedLengthUnknownWhenContentRangeSizeIsWildcard() async throws {
        respond(to: .head, status: .partialContent, headers: [
            "Content-Range": "bytes 0-1/*",
            "Content-Length": "2",
        ])

        let length = await resource.estimatedLength()
        try #expect(length.get() == nil)
    }

    @Test func estimatedLengthFromContentLength() async throws {
        respond(to: .head, headers: ["Content-Length": "2048"])

        let length = await resource.estimatedLength()
        try #expect(length.get() == 2048)
    }
}

// MARK: - Helpers

private extension HTTPResourceTests {
    /// Makes the server answer the requests of `method` with the given
    /// response.
    func respond(
        to method: HTTPRequest.Method,
        status: HTTPStatus = .ok,
        headers: [String: String] = [:],
        body: Data = Data()
    ) {
        client.fetchResults["\(method.rawValue) \(url.string)"] = .success(.init(
            response: HTTPResponse(
                request: HTTPRequest(url: url, method: method),
                url: url,
                status: status,
                headers: headers,
                mediaType: .epub
            ),
            body: body
        ))
    }

    /// Makes the requests of `method` fail with `error`.
    func fail(_ method: HTTPRequest.Method, with error: HTTPError) {
        client.fetchResults["\(method.rawValue) \(url.string)"] = .failure(error)
    }
}
