//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

@Suite(.serialized)
struct DefaultHTTPClientTests {
    @Suite(.serialized)
    struct UserAgent {
        @Test("Default user agent is set when none provided on request")
        @MainActor func defaultUserAgentIsSet() async {
            let receivedUserAgent = Capture<String?>(nil)

            let client = makeClient { request in
                receivedUserAgent.value = request.value(forHTTPHeaderField: "User-Agent")
                return .success()
            }

            _ = await client.fetch(makeURL())

            #expect(receivedUserAgent.value == DefaultHTTPClient.defaultUserAgent)
        }

        @Test("Custom user agent overrides default")
        func customUserAgent() async {
            let receivedUserAgent = Capture<String?>(nil)
            let customUA = "MyApp/1.0"

            let client = makeClient(userAgent: customUA) { request in
                receivedUserAgent.value = request.value(forHTTPHeaderField: "User-Agent")
                return .success()
            }

            _ = await client.fetch(makeURL())

            #expect(receivedUserAgent.value == customUA)
        }

        @Test("Per-request user agent takes precedence over client default")
        func perRequestUserAgent() async {
            let receivedUserAgent = Capture<String?>(nil)
            let requestUA = "RequestSpecific/2.0"

            let client = makeClient(userAgent: "ClientDefault/1.0") { request in
                receivedUserAgent.value = request.value(forHTTPHeaderField: "User-Agent")
                return .success()
            }

            var request = HTTPRequest(url: makeURL())
            request.userAgent = requestUA
            _ = await client.fetch(request)

            #expect(receivedUserAgent.value == requestUA)
        }
    }

    @Suite(.serialized)
    struct Headers {
        @Test("Additional headers from configuration are sent")
        func additionalHeaders() async {
            let receivedHeader = Capture<String?>(nil)

            let client = makeClient(additionalHeaders: ["X-Custom": "hello"]) { request in
                receivedHeader.value = request.value(forHTTPHeaderField: "X-Custom")
                return .success()
            }

            _ = await client.fetch(makeURL())

            #expect(receivedHeader.value == "hello")
        }

        @Test("Per-request headers are sent")
        func perRequestHeaders() async {
            let receivedHeader = Capture<String?>(nil)

            let client = makeClient { request in
                receivedHeader.value = request.value(forHTTPHeaderField: "X-Request")
                return .success()
            }

            let request = HTTPRequest(url: makeURL(), headers: ["X-Request": "value"])
            _ = await client.fetch(request)

            #expect(receivedHeader.value == "value")
        }
    }

    @Suite(.serialized)
    struct Streaming {
        @Test("Stream delivers data in chunks")
        func streamDeliversChunks() async throws {
            let chunk1 = Data("hello ".utf8)
            let chunk2 = Data("world".utf8)

            let client = makeClient { _ in
                .success(chunks: [chunk1, chunk2])
            }

            let receivedChunks = Capture<[Data]>([])

            let result = await client.stream(makeURL()) { data, _ in
                receivedChunks.value.append(data)
                return .success(())
            }

            let response = try result.get()
            #expect(response.status == .ok)
            // URLSession coalesces chunks, so verify total data.
            let totalData = receivedChunks.value.reduce(Data(), +)
            #expect(totalData == chunk1 + chunk2)
        }

        @Test("Stream reports progress when Content-Length is known")
        func streamReportsProgress() async {
            let body = Data("hello world".utf8)

            let lastProgress = Capture<Double?>(nil)

            let client = makeClient { _ in
                .success(
                    headers: ["Content-Length": "\(body.count)"],
                    body: body
                )
            }

            _ = await client.stream(makeURL()) { _, progress in
                if let progress = progress {
                    lastProgress.value = progress
                }
                return .success(())
            }

            // Final progress should be 1.0 (all data received)
            #expect(lastProgress.value == 1.0)
        }

        @Test("Stream reports nil progress when Content-Length is unknown")
        func streamReportsNilProgressWhenContentLengthUnknown() async throws {
            let progress = Capture<Double?>(nil)

            let client = makeClient { _ in
                .success(body: Data("data".utf8))
            }

            let result = await client.stream(makeURL()) { _, p in
                if let p {
                    progress.value = p
                }
                return .success(())
            }

            _ = try result.get()
            #expect(progress.value == nil)
        }

        @Test("onReceiveResponse receives correct response metadata")
        func onReceiveResponseReceivesCorrectMetadata() async {
            let receivedResponse = Capture<HTTPResponse?>(nil)

            let client = makeClient { _ in
                .success(
                    headers: ["X-Custom": "test-value", "Content-Type": "text/plain"],
                    body: Data("hello".utf8)
                )
            }

            _ = await client.stream(
                makeURL(),
                onReceiveResponse: captureResponse(in: receivedResponse)
            ) { _, _ in .success(()) }

            let response = receivedResponse.value!
            #expect(response.status == .ok)
            #expect(response.valueForHeader("X-Custom") == "test-value")
        }

        @Test("onReceiveResponse success allows data to flow through consume")
        func onReceiveResponseSuccessAllowsDataToFlow() async throws {
            let body = Data("hello world".utf8)
            let receivedData = Capture(Data())

            let client = makeClient { _ in
                .success(body: body)
            }

            let result = await client.stream(
                makeURL(),
                onReceiveResponse: { _ in .success(()) }
            ) { data, _ in
                receivedData.value.append(data)
                return .success(())
            }

            _ = try result.get()
            #expect(receivedData.value == body)
        }

        @Test("onReceiveResponse is called before consume receives data")
        func onReceiveResponseIsCalledBeforeConsume() async {
            let callOrder = Mutex<[String]>([])

            let client = makeClient { _ in
                .success(body: Data("data".utf8))
            }

            _ = await client.stream(
                makeURL(),
                onReceiveResponse: { _ in
                    callOrder.withLock { $0.append("onReceiveResponse") }
                    return .success(())
                }
            ) { _, _ in
                callOrder.withLock { $0.append("consume") }
                return .success(())
            }

            let order = callOrder.withLock { $0 }
            #expect(order.first == "onReceiveResponse")
            #expect(order.contains("consume"))
        }

        @Test("onReceiveResponse is not called for HTTP error responses")
        func onReceiveResponseNotCalledOnHTTPError() async {
            let called = Capture(false)

            let client = makeClient { _ in
                .success(statusCode: 401)
            }

            _ = await client.stream(
                makeURL(),
                onReceiveResponse: { _ in
                    called.value = true
                    return .success(())
                }
            ) { _, _ in .success(()) }

            #expect(!called.value)
        }

        @Test("Returning failure from onReceiveResponse aborts the stream")
        func onReceiveResponseFailureAbortsStream() async {
            let client = makeClient { _ in .success() }

            let result = await client.stream(
                makeURL(),
                onReceiveResponse: { _ in .failure(.offline(nil)) }
            ) { _, _ in .success(()) }

            guard case .failure(.offline(nil)) = result else {
                Issue.record("Expected .offline failure but got \(result)")
                return
            }
        }

        @Test("Returning failure from consume aborts the stream")
        func consumeFailureAbortsStream() async {
            let largeBody = Data(repeating: 0x42, count: 1024)

            let client = makeClient { _ in
                .success(
                    headers: ["Content-Length": "\(largeBody.count)"],
                    chunks: [
                        Data(largeBody[0 ..< 512]),
                        Data(largeBody[512...]),
                    ]
                )
            }

            let result = await client.stream(makeURL()) { _, _ in
                .failure(.offline(nil))
            }

            guard case .failure(.offline(nil)) = result else {
                Issue.record("Expected .offline failure but got \(result)")
                return
            }
        }
    }

    @Suite(.serialized)
    struct Fetch {
        @Test("Fetch accumulates streamed data into response body")
        func fetchAccumulatesData() async throws {
            let chunk1 = Data("hello ".utf8)
            let chunk2 = Data("world".utf8)

            let client = makeClient { _ in
                .success(chunks: [chunk1, chunk2])
            }

            let response = try await client.fetch(makeURL()).get()

            #expect(response.body == chunk1 + chunk2)
        }

        @Test("Fetch returns correct media type")
        func fetchReturnsMetadata() async throws {
            let client = makeClient { _ in
                .success(
                    headers: [
                        "Content-Type": "text/plain",
                    ]
                )
            }

            let response = try await client.fetch(makeURL()).get()

            #expect(response.mediaType?.string == "text/plain")
        }

        @Test("fetchString returns decoded string")
        func fetchString() async throws {
            let text = "Hello, Readium!"

            let client = makeClient { _ in
                .success(
                    headers: ["Content-Type": "text/plain; charset=utf-8"],
                    body: Data(text.utf8)
                )
            }

            let result = try await client.fetchString(makeURL()).get()
            #expect(result == text)
        }

        @Test("fetchJSON parses a JSON object")
        func fetchJSON() async throws {
            let client = makeClient { _ in
                .success(
                    headers: ["Content-Type": "application/json"],
                    body: Data(#"{"key": "value"}"#.utf8)
                )
            }

            let json = try await client.fetchJSON(makeURL()).get()
            #expect(json["key"] as? String == "value")
        }

        @Test("fetch with decoder returns malformedResponse when decoder returns nil")
        func fetchDecoderReturnsNil() async {
            let client = makeClient { _ in
                .success(body: Data("not-json".utf8))
            }

            let result = await client.fetch(makeURL()) { _ in nil as String? }

            guard case .failure(.malformedResponse) = result else {
                Issue.record("Expected .malformedResponse, got \(result)")
                return
            }
        }

        @Test("fetch with decoder returns malformedResponse when decoder throws")
        func fetchDecoderThrows() async {
            struct DecoderError: Error {}

            let client = makeClient { _ in
                .success(body: Data("not-json".utf8))
            }

            let result = await client.fetch(makeURL()) { _ -> String? in
                throw DecoderError()
            }

            guard case .failure(.malformedResponse) = result else {
                Issue.record("Expected .malformedResponse, got \(result)")
                return
            }
        }
    }

    @Suite(.serialized)
    struct Download {
        @Test("Download writes data to a temporary file")
        func downloadWritesToFile() async throws {
            let content = Data("file content".utf8)

            let client = makeClient { _ in
                .success(
                    headers: [
                        "Content-Length": "\(content.count)",
                        "Content-Type": "application/octet-stream",
                    ],
                    body: content
                )
            }

            let download = try await client
                .download(makeURL()) { _ in }
                .get()

            #expect(download.suggestedFilename == nil)

            let downloadedData = try Data(contentsOf: download.location.url)
            #expect(downloadedData == content)

            try FileManager.default.removeItem(at: download.location.url)
        }

        @Test("Download reports progress")
        func downloadReportsProgress() async throws {
            let content = Data(repeating: 0x42, count: 1024)

            let client = makeClient { _ in
                .success(
                    headers: ["Content-Length": "\(content.count)"],
                    body: content
                )
            }

            let lastProgress = Mutex<Double?>(nil)

            let download = try await client
                .download(makeURL()) { progress in
                    lastProgress.withLock { $0 = progress }
                }
                .get()

            #expect(lastProgress.withLock { $0 } == 1.0)

            try FileManager.default.removeItem(at: download.location.url)
        }

        @Test("Download cleans up temporary file on failure")
        func downloadCleansUpOnFailure() async {
            let client = makeClient { _ in
                .success(statusCode: 500, body: Data("error".utf8))
            }

            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let countBefore = (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path))?.count ?? 0

            let result = await client
                .download(makeURL()) { _ in }

            let countAfter = (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path))?.count ?? 0

            guard case .failure = result else {
                Issue.record("Expected failure")
                return
            }
            #expect(countAfter == countBefore, "Temporary file should be deleted on failure")
        }

        @Test("Download preserves suggested filename from Content-Disposition")
        func downloadSuggestedFilename() async throws {
            let client = makeClient { _ in
                .success(
                    headers: [
                        "Content-Disposition": "attachment; filename=book.epub",
                        "Content-Type": "application/epub+zip",
                    ],
                    body: Data("epub".utf8)
                )
            }

            let download = try await client
                .download(makeURL()) { _ in }
                .get()

            #expect(download.suggestedFilename == "book.epub")

            try FileManager.default.removeItem(at: download.location.url)
        }

        @Test("Download preserves RFC 5987 encoded filename from Content-Disposition")
        func downloadRFC5987Filename() async throws {
            let client = makeClient { _ in
                .success(
                    headers: [
                        "Content-Disposition": "attachment; filename*=UTF-8''bel%C3%A9tr%C3%A9s.epub",
                        "Content-Type": "application/epub+zip",
                    ],
                    body: Data("epub".utf8)
                )
            }

            let download = try await client
                .download(makeURL()) { _ in }
                .get()

            #expect(download.suggestedFilename == "belétrés.epub")

            try FileManager.default.removeItem(at: download.location.url)
        }

        @Test("Download returns the media type from Content-Type")
        func downloadMediaType() async throws {
            let client = makeClient { _ in
                .success(
                    headers: ["Content-Type": "application/epub+zip"],
                    body: Data("epub".utf8)
                )
            }

            let download = try await client
                .download(makeURL()) { _ in }
                .get()

            #expect(download.mediaType == MediaType.epub)

            try FileManager.default.removeItem(at: download.location.url)
        }
    }

    @Suite(.serialized)
    struct HTTPErrors {
        @Test(
            "HTTP error status codes return .errorResponse",
            arguments: [400, 401, 403, 404, 405, 500]
        )
        func httpErrorStatusCodes(statusCode: HTTPStatus) async {
            let client = makeClient { _ in
                .success(statusCode: statusCode, body: Data())
            }

            let result = await client.fetch(makeURL())

            guard case let .failure(.errorResponse(response)) = result else {
                Issue.record("Expected .errorResponse for status \(statusCode)")
                return
            }
            #expect(response.status == statusCode)
        }

        @Test("Error response body is accumulated")
        func errorResponseIncludesBody() async {
            let errorBody = Data("""
            {"type": "https://example.com/auth", "title": "Authentication Required"}
            """.utf8)

            let client = makeClient { _ in
                .success(
                    statusCode: 401,
                    headers: ["Content-Type": "application/problem+json"],
                    body: errorBody
                )
            }

            let result = await client.fetch(makeURL())

            guard case let .failure(.errorResponse(response)) = result else {
                Issue.record("Expected .errorResponse")
                return
            }
            #expect(response.body == errorBody)
        }

        @Test(
            "2xx status codes are treated as success",
            arguments: [200, 201, 204]
        )
        func successStatusCodes(statusCode: HTTPStatus) async {
            let client = makeClient { _ in
                .success(statusCode: statusCode, body: Data("ok".utf8))
            }

            let result = await client.fetch(makeURL())

            guard case .success = result else {
                Issue.record("Status \(statusCode) should be success but got \(result)")
                return
            }
        }
    }

    @Suite(.serialized)
    struct Redirects {
        @Test("HTTP redirects are followed automatically")
        func redirectsAreFollowedAutomatically() async throws {
            let client = makeClient { request in
                switch request.url?.path {
                case "/final":
                    return .success(body: Data("final response".utf8))
                default:
                    return .redirect(to: makeURL("/final").url)
                }
            }

            let httpResponse = Capture<HTTPResponse?>(nil)

            let fetchResponse = try await client.fetch(
                makeURL(),
                onReceiveResponse: captureResponse(in: httpResponse)
            ).get()

            #expect(fetchResponse.body == Data("final response".utf8))
            #expect(httpResponse.value?.url.isEquivalentTo(makeURL("/final")) == true)
        }
    }

    @Suite(.serialized)
    struct NetworkErrors {
        @Test("URLError propagates to HTTPError")
        func urlErrorPropagation() async {
            let client = makeClient { _ in
                .error(URLError(.cannotConnectToHost))
            }

            let result = await client.fetch(makeURL())

            guard case .failure(.unreachable) = result else {
                Issue.record("Expected .unreachable error, got \(result)")
                return
            }
        }

        @Test("Timeout returns .timeout error")
        func timeoutError() async {
            let client = makeClient(requestTimeout: 1) { _ in
                .delayed(seconds: 60, then: .success())
            }

            let result = await client.fetch(makeURL())

            guard case .failure(.timeout) = result else {
                Issue.record("Expected .timeout error, got \(result)")
                return
            }
        }
    }

    @Suite(.serialized)
    struct Cancellation {
        @Test("Cancelling the Swift task cancels the HTTP request")
        func cancelledTaskReturnsCancelledError() async {
            let client = makeClient { _ in
                .delayed(seconds: 2, then: .success(body: Data("late".utf8)))
            }

            let task = Task {
                await client.fetch(makeURL())
            }

            // Give the request time to start, then cancel.
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            task.cancel()

            let result = await task.value

            guard case .failure(.cancelled) = result else {
                Issue.record("Expected failure after cancellation, got \(result)")
                return
            }
        }

        @Test("Cancelling the Swift task during an active stream returns .cancelled")
        func cancelledTaskDuringStreamReturnsCancelledError() async {
            // Use a real HTTP request, the MockURLProtocol cannot be used
            // reliably for this test.
            let client = DefaultHTTPClient()

            let task = Task {
                await client.stream(HTTPURL(string: "https://github.com/readium/swift-toolkit/archive/refs/heads/develop.zip")!) { _, _ in .success(()) }
            }

            // Give the request time to start, then cancel before the end.
            try? await Task.sleep(seconds: 0.1)
            task.cancel()

            let result = await task.value

            guard case .failure(.cancelled) = result else {
                Issue.record("Expected .cancelled failure during stream, got \(result)")
                return
            }
        }

        @Test("Cancelled request returns .cancelled error")
        func cancelledError() async {
            let client = makeClient { _ in
                .error(URLError(.cancelled))
            }

            let result = await client.fetch(makeURL())

            guard case .failure(.cancelled) = result else {
                Issue.record("Expected .cancelled error, got \(result)")
                return
            }
        }
    }

    @Suite(.serialized)
    struct RangeRequests {
        @Test("Range request succeeds when server signals Accept-Ranges")
        func rangeRequestSuccessViaAcceptRanges() async throws {
            let partialContent = Data("partial".utf8)

            let client = makeClient { request in
                let rangeHeader = request.value(forHTTPHeaderField: "Range")
                #expect(rangeHeader != nil)

                return .success(
                    statusCode: 206,
                    headers: [
                        "Accept-Ranges": "bytes",
                        "Content-Length": "\(partialContent.count)",
                    ],
                    body: partialContent
                )
            }

            var httpRequest = HTTPRequest(url: makeURL())
            httpRequest.setRange(0 ..< 7)

            let response = Capture<HTTPResponse?>(nil)
            let result = try await client.fetch(
                httpRequest,
                onReceiveResponse: captureResponse(in: response)
            ).get()

            #expect(response.value?.status == .partialContent)
            #expect(result.body == partialContent)
        }

        @Test("Range request succeeds when server signals Content-Range without Accept-Ranges")
        func rangeRequestSuccessViaContentRange() async throws {
            let partialContent = Data("partial".utf8)

            let client = makeClient { _ in
                .success(
                    statusCode: 206,
                    headers: [
                        "Content-Range": "bytes 0-6/100",
                        "Content-Length": "\(partialContent.count)",
                    ],
                    body: partialContent
                )
            }

            var httpRequest = HTTPRequest(url: makeURL())
            httpRequest.setRange(0 ..< 7)

            let response = Capture<HTTPResponse?>(nil)
            let result = try await client.fetch(
                httpRequest,
                onReceiveResponse: captureResponse(in: response)
            ).get()

            #expect(response.value?.status == .partialContent)
            #expect(result.body == partialContent)
        }

        @Test("Range request fails when server does not support byte ranges")
        func rangeRequestFailsWithoutServerSupport() async {
            let client = makeClient { _ in
                .success(
                    statusCode: 200,
                    headers: [:],
                    body: Data("full content".utf8)
                )
            }

            var httpRequest = HTTPRequest(url: makeURL())
            httpRequest.setRange(0 ..< 7)

            let result = await client.fetch(httpRequest)

            guard case .failure(.rangeNotSupported) = result else {
                Issue.record("Expected .rangeNotSupported, got \(result)")
                return
            }
        }

        @Test("Open-ended setRange omits upper bound in Range header")
        func openEndedRangeRequest() async {
            let receivedRange = Capture<String?>(nil)

            let client = makeClient { request in
                receivedRange.value = request.value(forHTTPHeaderField: "Range")
                return .success(
                    statusCode: 206,
                    headers: ["Accept-Ranges": "bytes"],
                    body: Data("tail".utf8)
                )
            }

            var httpRequest = HTTPRequest(url: makeURL())
            httpRequest.setRange(5...)
            _ = await client.fetch(httpRequest)

            #expect(receivedRange.value == "bytes=5-")
        }
    }

    @Suite(.serialized)
    struct DelegateCallbacks {
        @Test("willStartRequest is called before the request")
        func willStartRequestIsCalled() async {
            let delegate = SpyDelegate()
            let client = makeClient(delegate: delegate) { _ in
                .success()
            }

            _ = await client.fetch(makeURL())

            #expect(delegate.willStartRequestCalled)
        }

        @Test("willStartRequest can modify the request")
        func willStartRequestModifiesRequest() async {
            let receivedHeader = Capture<String?>(nil)

            let delegate = SpyDelegate()
            delegate.onWillStartRequest = { request in
                var modified = request
                modified.headers["X-Injected"] = "by-delegate"
                return .success(modified)
            }

            let client = makeClient(delegate: delegate) { request in
                receivedHeader.value = request.value(forHTTPHeaderField: "X-Injected")
                return .success()
            }

            _ = await client.fetch(makeURL())

            #expect(receivedHeader.value == "by-delegate")
        }

        @Test("willStartRequest returning failure aborts the request without sending it")
        func willStartRequestFailureAbortsRequest() async {
            let delegate = SpyDelegate()
            delegate.onWillStartRequest = { _ in
                .failure(.cancelled)
            }

            let client = makeClient(delegate: delegate) { _ in
                Issue.record("Request should not have been sent")
                return .success(body: Data())
            }

            let result = await client.fetch(makeURL())

            guard case .failure(.cancelled) = result else {
                Issue.record("Expected .cancelled from willStartRequest failure, got \(result)")
                return
            }
            #expect(!delegate.didFailWithErrorCalled)
        }

        @Test("didReceiveResponse is called on success")
        func didReceiveResponseIsCalled() async {
            let delegate = SpyDelegate()
            let client = makeClient(delegate: delegate) { _ in
                .success()
            }

            _ = await client.fetch(makeURL())

            #expect(delegate.didReceiveResponseCalled)
        }

        @Test("didReceiveResponse is called for error HTTP responses")
        func didReceiveResponseIsCalledForErrors() async {
            let delegate = SpyDelegate()
            let client = makeClient(delegate: delegate) { _ in
                .success(statusCode: 401, body: Data("unauthorized".utf8))
            }

            _ = await client.fetch(makeURL())

            #expect(delegate.didReceiveResponseCalled)
            #expect(delegate.lastResponse?.status == .unauthorized)
        }

        @Test("didFailWithError is called on failure")
        func didFailWithErrorIsCalled() async {
            let delegate = SpyDelegate()
            let client = makeClient(delegate: delegate) { _ in
                .error(URLError(.timedOut))
            }

            _ = await client.fetch(makeURL())

            #expect(delegate.didFailWithErrorCalled)
        }

        @Test("recoverRequest can retry with a new request")
        func recoverRequestRetries() async throws {
            let requestCount = Capture(0)

            let delegate = SpyDelegate()
            delegate.onRecoverRequest = { request, _ in
                // Retry the same request
                .success(request)
            }

            let client = makeClient(delegate: delegate) { _ in
                requestCount.value += 1
                if requestCount.value == 1 {
                    return .error(URLError(.timedOut))
                }
                return .success(body: Data("recovered".utf8))
            }

            let result = await client.fetch(makeURL())

            let response = try result.get()
            #expect(response.body == Data("recovered".utf8))
            #expect(requestCount.value == 2)
        }

        @Test("recoverRequest propagates error when unrecoverable")
        func recoverRequestPropagatesError() async {
            let delegate = SpyDelegate()
            delegate.onRecoverRequest = { _, error in
                .failure(error)
            }

            let client = makeClient(delegate: delegate) { _ in
                .error(URLError(.timedOut))
            }

            let result = await client.fetch(makeURL())

            guard case .failure(.timeout) = result else {
                Issue.record("Expected .timeout, got \(result)")
                return
            }
            #expect(delegate.didFailWithErrorCalled)
        }

        @Test("willStartRequest can redirect to a different URL")
        func willStartRequestRedirects() async throws {
            let delegate = SpyDelegate()
            delegate.onWillStartRequest = { _ in
                let redirectURL = HTTPURL(string: "https://example.com/redirected")!
                return .success(HTTPRequest(url: redirectURL))
            }

            let client = makeClient(delegate: delegate) { request in
                switch request.url?.path {
                case "/redirected":
                    return .success(body: Data("redirected response".utf8))
                default:
                    return .success(statusCode: 404, body: Data())
                }
            }

            let response = try await client.fetch(makeURL()).get()
            #expect(response.body == Data("redirected response".utf8))
        }
    }

    @Suite(.serialized)
    struct AuthenticationChallenges {
        @Test("Delegate receives authentication challenge")
        func delegateReceivesChallenge() async {
            let delegate = SpyDelegate()
            delegate.onDidReceiveChallenge = { _ in
                .performDefaultHandling
            }

            let client = makeClient(delegate: delegate) { _ in
                .authenticationChallenge(
                    host: "example.com",
                    method: NSURLAuthenticationMethodHTTPBasic,
                    then: .success(body: Data("authenticated".utf8))
                )
            }

            _ = await client.fetch(makeURL())

            #expect(delegate.didReceiveChallengeCalled)
        }

        @Test("Using credentials succeeds after authentication challenge")
        func useCredentialSucceeds() async throws {
            let delegate = SpyDelegate()
            delegate.onDidReceiveChallenge = { _ in
                let credential = URLCredential(user: "user", password: "pass", persistence: .none)
                return .useCredential(credential)
            }

            let client = makeClient(delegate: delegate) { _ in
                .authenticationChallenge(
                    host: "example.com",
                    method: NSURLAuthenticationMethodHTTPBasic,
                    then: .success(body: Data("authenticated".utf8))
                )
            }

            let result = try await client.fetch(makeURL()).get()
            #expect(result.body == Data("authenticated".utf8))
        }

        @Test("Cancelling authentication fails with HTTPError.cancelled")
        func cancellingAuthenticationChallengePropagates() async {
            let delegate = SpyDelegate()
            delegate.onDidReceiveChallenge = { _ in
                .cancelAuthenticationChallenge
            }

            let client = makeClient(delegate: delegate) { _ in
                .authenticationChallenge(
                    host: "example.com",
                    method: NSURLAuthenticationMethodHTTPBasic,
                    then: .success(body: Data("authenticated".utf8))
                )
            }

            let result = await client.fetch(makeURL())

            guard case .failure(.cancelled) = result else {
                Issue.record("Expected HTTPError.cancelled when cancelling an authentication challenge")
                return
            }
        }
    }

    @Suite(.serialized)
    struct Configuration {
        @Test("Request timeout is passed to URLSessionConfiguration")
        func requestTimeoutIsApplied() async {
            let receivedTimeout = Capture<TimeInterval?>(nil)

            let client = makeClient(requestTimeout: 42) { request in
                receivedTimeout.value = request.timeoutInterval
                return .success()
            }

            _ = await client.fetch(makeURL())
            #expect(receivedTimeout.value == 42)
        }

        @Test("Per-request timeout overrides session timeout")
        func perRequestTimeoutOverridesSession() async {
            let receivedTimeout = Capture<TimeInterval?>(nil)

            let client = makeClient(requestTimeout: 60.0) { request in
                receivedTimeout.value = request.timeoutInterval
                return .success()
            }

            var request = HTTPRequest(url: makeURL())
            request.timeoutInterval = 5.0
            _ = await client.fetch(request)

            #expect(receivedTimeout.value == 5.0)
        }

        @Test("HTTP method is correctly transmitted")
        func httpMethodIsTransmitted() async {
            let receivedMethod = Capture<String?>(nil)

            let client = makeClient { request in
                receivedMethod.value = request.httpMethod
                return .success()
            }

            let request = HTTPRequest(url: makeURL(), method: .post)
            _ = await client.fetch(request)

            #expect(receivedMethod.value == "POST")
        }

        @Test("Request body is transmitted for POST requests")
        func requestBodyIsTransmitted() async {
            let receivedBody = Capture<Data?>(nil)

            let client = makeClient { request in
                if let stream = request.httpBodyStream {
                    stream.open()
                    var data = Data()
                    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
                    defer { buffer.deallocate() }
                    while stream.hasBytesAvailable {
                        let bytesRead = stream.read(buffer, maxLength: 1024)
                        if bytesRead > 0 {
                            data.append(buffer, count: bytesRead)
                        }
                    }
                    stream.close()
                    receivedBody.value = data
                } else {
                    receivedBody.value = request.httpBody
                }
                return .success()
            }

            let bodyData = Data("request body".utf8)
            let request = HTTPRequest(url: makeURL(), method: .post, body: .data(bodyData))
            _ = await client.fetch(request)

            #expect(receivedBody.value == bodyData)
        }

        @Test("File body is transmitted for POST requests")
        func fileBodyIsTransmitted() async throws {
            let receivedBody = Capture<Data?>(nil)

            let client = makeClient { request in
                receivedBody.value = request.body()
                return .success()
            }

            let bodyData = Data("file body content".utf8)
            let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
            try bodyData.write(to: fileURL)
            defer { try? FileManager.default.removeItem(at: fileURL) }

            let request = HTTPRequest(url: makeURL(), method: .post, body: .file(fileURL))
            _ = await client.fetch(request)

            #expect(receivedBody.value == bodyData)
        }

        @Test("setPOSTForm sets POST method and URL-encodes form fields")
        func setPOSTFormEncodesData() async {
            let receivedMethod = Capture<String?>(nil)
            let receivedContentType = Capture<String?>(nil)
            let receivedBody = Capture<String?>(nil)

            let client = makeClient { request in
                receivedMethod.value = request.httpMethod
                receivedContentType.value = request.value(forHTTPHeaderField: "Content-Type")
                receivedBody.value = request.stringBody()
                return .success()
            }

            var request = HTTPRequest(url: makeURL())
            request.setPOSTForm(["name": "Alice", "age": "30"])
            _ = await client.fetch(request)

            #expect(receivedMethod.value == "POST")
            #expect(receivedContentType.value == "application/x-www-form-urlencoded")
            let body = receivedBody.value ?? ""
            #expect(body.contains("name=Alice"))
            #expect(body.contains("age=30"))
        }
    }
}

private extension URLRequest {
    func stringBody(encoding: String.Encoding = .utf8) -> String? {
        body().flatMap { String(data: $0, encoding: encoding) }
    }

    func body() -> Data? {
        if let httpBody {
            return httpBody
        } else if let stream = httpBodyStream {
            stream.open()
            var data = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let bytesRead = stream.read(buffer, maxLength: 1024)
                if bytesRead > 0 { data.append(buffer, count: bytesRead) }
            }
            stream.close()
            return data
        } else {
            return nil
        }
    }
}

/// Creates a `DefaultHTTPClient` configured with `MockURLProtocol`
/// for intercepting all requests.
private func makeClient(
    userAgent: String? = nil,
    additionalHeaders: [String: String]? = nil,
    requestTimeout: TimeInterval? = nil,
    resourceTimeout: TimeInterval? = nil,
    delegate: DefaultHTTPClientDelegate? = nil,
    handler: @escaping @Sendable (URLRequest) -> MockURLResponse
) -> DefaultHTTPClient {
    MockURLProtocol.handler = handler

    return DefaultHTTPClient(
        userAgent: userAgent,
        ephemeral: true,
        additionalHeaders: additionalHeaders,
        requestTimeout: requestTimeout,
        resourceTimeout: resourceTimeout,
        delegate: delegate,
        configure: { config in
            config.protocolClasses = [MockURLProtocol.self]
        }
    )
}

private func captureResponse(in response: Capture<HTTPResponse?>) -> @Sendable (HTTPResponse) -> HTTPResult<Void> {
    { resp in
        response.value = resp
        return .success(())
    }
}

private func makeURL(_ path: String = "/test") -> HTTPURL {
    HTTPURL(string: "https://example.com\(path)")!
}

/// A test spy implementing `DefaultHTTPClientDelegate` that records calls
/// and allows customizing behavior via closures.
private class SpyDelegate: DefaultHTTPClientDelegate, @unchecked Sendable {
    var willStartRequestCalled = false
    var didReceiveResponseCalled = false
    var didFailWithErrorCalled = false
    var didReceiveChallengeCalled = false

    var lastRequest: HTTPRequest?
    var lastResponse: HTTPResponse?
    var lastError: HTTPError?
    var lastChallenge: URLAuthenticationChallenge?

    var onWillStartRequest: ((HTTPRequest) -> HTTPResult<HTTPRequestConvertible>)?
    var onRecoverRequest: ((HTTPRequest, HTTPError) -> HTTPResult<HTTPRequestConvertible>)?
    var onDidReceiveChallenge: ((URLAuthenticationChallenge) -> URLAuthenticationChallengeResponse)?

    func httpClient(
        _ httpClient: DefaultHTTPClient,
        willStartRequest request: HTTPRequest
    ) async -> HTTPResult<HTTPRequestConvertible> {
        willStartRequestCalled = true
        lastRequest = request
        return onWillStartRequest?(request) ?? .success(request)
    }

    func httpClient(
        _ httpClient: DefaultHTTPClient,
        recoverRequest request: HTTPRequest,
        fromError error: HTTPError
    ) async -> HTTPResult<HTTPRequestConvertible> {
        onRecoverRequest?(request, error) ?? .failure(error)
    }

    func httpClient(
        _ httpClient: DefaultHTTPClient,
        request: HTTPRequest,
        didReceiveResponse response: HTTPResponse
    ) {
        didReceiveResponseCalled = true
        lastResponse = response
    }

    func httpClient(
        _ httpClient: DefaultHTTPClient,
        request: HTTPRequest,
        didFailWithError error: HTTPError
    ) {
        didFailWithErrorCalled = true
        lastError = error
    }

    func httpClient(
        _ httpClient: DefaultHTTPClient,
        request: HTTPRequest,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> URLAuthenticationChallengeResponse {
        didReceiveChallengeCalled = true
        lastChallenge = challenge
        return onDidReceiveChallenge?(challenge) ?? .performDefaultHandling
    }
}
