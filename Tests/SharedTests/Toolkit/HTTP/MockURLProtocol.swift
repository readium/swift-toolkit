//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@preconcurrency import Foundation
@testable import ReadiumShared

/// A `URLProtocol` subclass that intercepts HTTP requests for testing
/// `DefaultHTTPClient` without hitting the network.
///
/// Configure the static `handler` before each test to control
/// the response returned for intercepted requests.
final class MockURLProtocol: Foundation.URLProtocol {
    /// Handler called for each intercepted request. Returns the response
    /// configuration to simulate.
    ///
    /// Must be set before starting a request.
    static var handler: (@Sendable (URLRequest) -> MockURLResponse)? {
        get { _handler.withLock { $0 } }
        set { _handler.withLock { $0 = newValue } }
    }

    private static let _handler = Mutex<(@Sendable (URLRequest) -> MockURLResponse)?>(nil)

    private let pendingTask = Mutex<Task<Void, Never>?>(nil)

    func setPendingTask(_ task: Task<Void, Never>?) {
        pendingTask.withLock {
            $0?.cancel()
            $0 = task
        }
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            fatalError("MockURLProtocol.handler is not set.")
        }
        guard let client else { return }
        deliver(handler(request), proto: self, to: client, for: request)
    }

    override func stopLoading() {
        setPendingTask(nil)
    }
}

/// Describes a mock response to return for an intercepted request.
indirect enum MockURLResponse: Sendable {
    /// A successful response delivered as a sequence of data chunks.
    case success(
        statusCode: HTTPStatus = .ok,
        headers: [String: String] = [:],
        chunks: [Data]
    )

    /// A simulated network error.
    case error(URLError)

    /// A response that is delivered after a delay, useful for timeout
    /// testing. Delivery is cancelled early if `stopLoading()` is called.
    case delayed(
        seconds: TimeInterval,
        then: MockURLResponse
    )

    /// An authentication challenge, followed by a response if the
    /// challenge is resolved successfully.
    case authenticationChallenge(
        host: String = "example.com",
        method: String = NSURLAuthenticationMethodHTTPBasic,
        then: MockURLResponse
    )

    /// A redirect response. The URL loading system handles the redirect,
    /// which triggers a new request cycle (calling `handler` again
    /// with the new URL).
    case redirect(
        to: URL,
        statusCode: HTTPStatus = 302
    )

    /// Convenience for a simple success response with a single body.
    static func success(
        statusCode: HTTPStatus = .ok,
        headers: [String: String] = [:],
        body: Data = Data("ok".utf8)
    ) -> MockURLResponse {
        .success(statusCode: statusCode, headers: headers, chunks: [body])
    }
}

/// Encapsulates all context needed for delivery.
private struct DeliveryContext: @unchecked Sendable {
    let proto: MockURLProtocol
    let client: URLProtocolClient
    let request: URLRequest
}

private func deliver(
    _ response: MockURLResponse,
    proto: MockURLProtocol,
    to client: URLProtocolClient,
    for request: URLRequest
) {
    deliver(response, ctx: DeliveryContext(proto: proto, client: client, request: request))
}

private func deliver(_ response: MockURLResponse, ctx: DeliveryContext) {
    switch response {
    case let .success(statusCode, headers, chunks):
        deliverSuccess(
            statusCode: statusCode,
            headers: headers,
            chunks: chunks,
            proto: ctx.proto,
            to: ctx.client,
            for: ctx.request
        )

    case let .error(urlError):
        ctx.client.urlProtocol(ctx.proto, didFailWithError: urlError)

    case let .delayed(seconds, then):
        ctx.proto.setPendingTask(Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                deliver(then, ctx: ctx)
            } catch {
                // Cancelled by stopLoading()
            }
        })

    case let .authenticationChallenge(host, method, then):
        let challengeSender = MockAuthChallengeSender { disposition in
            switch disposition {
            case .useCredential, .performDefaultHandling:
                deliver(then, ctx: ctx)
            case .cancelAuthenticationChallenge:
                ctx.client.urlProtocol(ctx.proto, didFailWithError: URLError(.userCancelledAuthentication))
            case .rejectProtectionSpace:
                ctx.client.urlProtocol(ctx.proto, didFailWithError: URLError(.userAuthenticationRequired))
            @unknown default:
                deliver(then, ctx: ctx)
            }
        }

        let protectionSpace = URLProtectionSpace(
            host: host,
            port: 443,
            protocol: "https",
            realm: "Test",
            authenticationMethod: method
        )
        let challenge = URLAuthenticationChallenge(
            protectionSpace: protectionSpace,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: challengeSender
        )
        ctx.client.urlProtocol(ctx.proto, didReceive: challenge)

    case let .redirect(location, statusCode):
        guard let originalURL = ctx.request.url,
              let response = HTTPURLResponse(
                  url: originalURL,
                  statusCode: statusCode.rawValue,
                  httpVersion: "HTTP/1.1",
                  headerFields: ["Location": location.absoluteString]
              )
        else {
            ctx.client.urlProtocol(ctx.proto, didFailWithError: URLError(.badServerResponse))
            return
        }

        var redirectedRequest = ctx.request
        redirectedRequest.url = location

        ctx.client.urlProtocol(
            ctx.proto,
            wasRedirectedTo: redirectedRequest,
            redirectResponse: response
        )
    }
}

private func deliverSuccess(
    statusCode: HTTPStatus,
    headers: [String: String],
    chunks: [Data],
    proto: Foundation.URLProtocol,
    to client: URLProtocolClient,
    for request: URLRequest
) {
    guard
        let url = request.url,
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode.rawValue,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )
    else {
        client.urlProtocol(proto, didFailWithError: URLError(.badServerResponse))
        return
    }

    client.urlProtocol(proto, didReceive: response, cacheStoragePolicy: .notAllowed)

    for chunk in chunks {
        client.urlProtocol(proto, didLoad: chunk)
    }

    client.urlProtocolDidFinishLoading(proto)
}

// MARK: - MockAuthChallengeSender

private final class MockAuthChallengeSender: NSObject, URLAuthenticationChallengeSender, @unchecked Sendable {
    private let onDisposition: @Sendable (URLSession.AuthChallengeDisposition) -> Void

    init(onDisposition: @escaping @Sendable (URLSession.AuthChallengeDisposition) -> Void) {
        self.onDisposition = onDisposition
        super.init()
    }

    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {
        onDisposition(.useCredential)
    }

    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {
        onDisposition(.performDefaultHandling)
    }

    func cancel(_ challenge: URLAuthenticationChallenge) {
        onDisposition(.cancelAuthenticationChallenge)
    }

    func performDefaultHandling(for challenge: URLAuthenticationChallenge) {
        onDisposition(.performDefaultHandling)
    }

    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {
        onDisposition(.rejectProtectionSpace)
    }
}
