//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public enum URLAuthenticationChallengeResponse: Sendable {
    /// Use the specified credential.
    case useCredential(URLCredential)
    /// Use the default handling for the challenge as though this delegate
    /// method were not implemented.
    case performDefaultHandling
    /// Cancel the entire request.
    case cancelAuthenticationChallenge
    /// Reject this challenge, and call the authentication delegate method again
    /// with the next authentication protection space.
    case rejectProtectionSpace
}

/// Delegate protocol for `DefaultHTTPClient`.
public protocol DefaultHTTPClientDelegate: AnyObject, Sendable {
    /// Tells the delegate that the HTTP client will start a new `request`.
    ///
    /// You can modify the `request`, for example by adding additional HTTP
    /// headers or redirecting to a different URL, before returning the new
    /// request.
    ///
    /// - Note: If this method returns a failure, the request is aborted
    /// immediately and `httpClient(_:request:didFailWithError:)` is NOT called.
    func httpClient(
        _ httpClient: DefaultHTTPClient,
        willStartRequest request: HTTPRequest
    ) async -> HTTPResult<HTTPRequestConvertible>

    /// Asks the delegate to recover from an `error` received for the given
    /// `request`.
    ///
    /// This can be used to implement custom authentication flows, for example.
    ///
    /// You can return either:
    /// - a new request to start
    /// - the `error` argument, if you cannot recover from it
    /// - a new `HTTPError` to provide additional information
    func httpClient(
        _ httpClient: DefaultHTTPClient,
        recoverRequest request: HTTPRequest,
        fromError error: HTTPError
    ) async -> HTTPResult<HTTPRequestConvertible>

    /// Tells the delegate that we received an HTTP response for the given
    /// `request`.
    ///
    /// You do not need to do anything with this `response`, which the HTTP
    /// client will handle. This is merely for informational purposes. For
    /// example, you could implement this to confirm that request credentials
    /// were successful.
    func httpClient(
        _ httpClient: DefaultHTTPClient,
        request: HTTPRequest,
        didReceiveResponse response: HTTPResponse
    )

    /// Tells the delegate that a `request` failed with the given `error`.
    ///
    /// You do not need to do anything with this `response`, which the HTTP
    /// client will handle. This is merely for informational purposes.
    ///
    /// This will be called only if `httpClient(_:recoverRequest:fromError:)`
    /// is not implemented, or returns an error. It is also NOT called if
    /// `httpClient(_:willStartRequest:)` fails and aborts the request.
    func httpClient(
        _ httpClient: DefaultHTTPClient,
        request: HTTPRequest,
        didFailWithError error: HTTPError
    )

    /// Requests credentials from the delegate in response to an authentication
    /// request from the remote server.
    func httpClient(
        _ httpClient: DefaultHTTPClient,
        request: HTTPRequest,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> URLAuthenticationChallengeResponse
}

public extension DefaultHTTPClientDelegate {
    func httpClient(_ httpClient: DefaultHTTPClient, willStartRequest request: HTTPRequest) async -> HTTPResult<HTTPRequestConvertible> {
        .success(request)
    }

    func httpClient(_ httpClient: DefaultHTTPClient, recoverRequest request: HTTPRequest, fromError error: HTTPError) async -> HTTPResult<HTTPRequestConvertible> {
        .failure(error)
    }

    func httpClient(_ httpClient: DefaultHTTPClient, request: HTTPRequest, didReceiveResponse response: HTTPResponse) {}
    func httpClient(_ httpClient: DefaultHTTPClient, request: HTTPRequest, didFailWithError error: HTTPError) {}

    func httpClient(
        _ httpClient: DefaultHTTPClient,
        request: HTTPRequest,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> URLAuthenticationChallengeResponse {
        .performDefaultHandling
    }
}

/// An implementation of `HTTPClient` using Apple's `URLSession`.
public final class DefaultHTTPClient: HTTPClient, Loggable {
    /// Returns the default user agent used when issuing requests.
    ///
    /// For example, TestApp/1.3
    public static let defaultUserAgent: String? = {
        let appInfo = Bundle.main.infoDictionary
        guard var userAgent = appInfo?["CFBundleName"] as? String else {
            return nil
        }
        if let appVersion = appInfo?["CFBundleShortVersionString"] as? String {
            userAgent.append("/\(appVersion)")
        }
        return userAgent
    }()

    private struct WeakDelegate: Sendable {
        weak var value: (any DefaultHTTPClientDelegate)?
    }

    private let _delegate: Mutex<WeakDelegate>

    public var delegate: (any DefaultHTTPClientDelegate)? {
        get { _delegate.withLock { $0.value } }
        set { _delegate.withLock { $0.value = newValue } }
    }

    private let session: URLSession
    private let userAgent: String?

    /// Creates a `DefaultHTTPClient` with common configuration settings.
    ///
    /// - Parameters:
    ///   - userAgent: Default user agent issued with requests.
    ///   - cachePolicy: Determines the request caching policy used by HTTP tasks.
    ///   - ephemeral: When true, uses no persistent storage for caches, cookies, or credentials.
    ///   - additionalHeaders: A dictionary of additional headers to send with requests.
    ///   - requestTimeout: The timeout interval to use when waiting for additional data.
    ///   - resourceTimeout: The maximum amount of time that a resource request should be allowed to take.
    ///   - delegate: An optional delegate to handle common HTTP events.
    ///   - configure: Callback used to configure further the `URLSessionConfiguration` object.
    public convenience init(
        userAgent: String? = nil,
        cachePolicy: URLRequest.CachePolicy? = nil,
        ephemeral: Bool = false,
        additionalHeaders: [String: String]? = nil,
        requestTimeout: TimeInterval? = nil,
        resourceTimeout: TimeInterval? = nil,
        delegate: (any DefaultHTTPClientDelegate)? = nil,
        configure: ((URLSessionConfiguration) -> Void)? = nil
    ) {
        let config: URLSessionConfiguration = ephemeral ? .ephemeral : .default
        config.httpAdditionalHeaders = additionalHeaders
        if let cachePolicy = cachePolicy {
            config.requestCachePolicy = cachePolicy
        }
        if let requestTimeout = requestTimeout {
            config.timeoutIntervalForRequest = requestTimeout
        }
        if let resourceTimeout = resourceTimeout {
            config.timeoutIntervalForResource = resourceTimeout
        }
        if let configure = configure {
            configure(config)
        }

        self.init(configuration: config, userAgent: userAgent, delegate: delegate)
    }

    /// Creates a `DefaultHTTPClient` with a custom configuration.
    ///
    /// - Parameters:
    ///   - configuration: The `URLSessionConfiguration` used for all requests.
    ///   - userAgent: Default user agent issued with requests.
    ///   - delegate: An optional delegate to handle common HTTP events.
    public init(
        configuration: URLSessionConfiguration,
        userAgent: String? = nil,
        delegate: (any DefaultHTTPClientDelegate)? = nil
    ) {
        self.userAgent = userAgent ?? DefaultHTTPClient.defaultUserAgent
        _delegate = Mutex(WeakDelegate(value: delegate))
        session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
    }

    deinit {
        session.invalidateAndCancel()
    }

    public func stream(
        _ request: any HTTPRequestConvertible,
        onReceiveResponse: (@Sendable (HTTPResponse) async -> HTTPResult<Void>)? = nil,
        consume: @Sendable (Data, Double?) -> HTTPResult<Void>
    ) async -> HTTPResult<HTTPResponse> {
        await request.httpRequest()
            .asyncFlatMap(willStartRequest)
            .asyncFlatMap { request in
                let result = await startTask(for: request, onReceiveResponse: onReceiveResponse, consume: consume)
                    .asyncRecover { error in
                        await recover(request, from: error)
                            .asyncFlatMap { newRequest in
                                await streamOnce(request: newRequest, onReceiveResponse: onReceiveResponse, consume: consume)
                            }
                    }

                if case let .failure(error) = result {
                    if case .cancelled = error {
                        // no-op
                    } else {
                        log(.error, "\(request.method) \(request.url) failed with:\n\(error)")
                        delegate?.httpClient(self, request: request, didFailWithError: error)
                    }
                }

                return result
            }
    }

    private func streamOnce(
        request: any HTTPRequestConvertible,
        onReceiveResponse: (@Sendable (HTTPResponse) async -> HTTPResult<Void>)?,
        consume: @Sendable (Data, Double?) -> HTTPResult<Void>
    ) async -> HTTPResult<HTTPResponse> {
        await request.httpRequest()
            .asyncFlatMap { request in
                await startTask(for: request, onReceiveResponse: onReceiveResponse, consume: consume)
            }
    }

    /// Creates and starts an async byte stream for the `request`.
    private func startTask(
        for request: HTTPRequest,
        onReceiveResponse: (@Sendable (HTTPResponse) async -> HTTPResult<Void>)?,
        consume: @Sendable (Data, Double?) -> HTTPResult<Void>
    ) async -> HTTPResult<HTTPResponse> {
        var request = request
        if request.userAgent == nil {
            request.userAgent = userAgent
        }

        log(.info, request)

        let taskDelegate = TaskDelegate(
            request: request,
            delegate: delegate,
            client: self
        )

        do {
            let task = session.dataTask(with: makeURLRequest(request))
            task.delegate = taskDelegate

            return try await withTaskCancellationHandler {
                let (stream, response) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(AsyncThrowingStream<Data, Error>, URLResponse), Error>) in
                    taskDelegate.setResponseContinuation(continuation)
                    task.resume()
                }

                guard let httpURLResponse = response as? HTTPURLResponse, let url = httpURLResponse.url?.httpURL else {
                    return .failure(.malformedResponse(nil))
                }

                let httpResponse = makeHTTPResponse(request: request, response: httpURLResponse, url: url)
                delegate?.httpClient(self, request: request, didReceiveResponse: httpResponse)

                if !httpResponse.status.isSuccess {
                    let body = try await collectErrorBody(from: stream, task: task)
                    return .failure(.errorResponse(makeErrorResponse(httpResponse: httpResponse, body: body)))
                }

                if request.hasHeader("Range"), !httpResponse.acceptsByteRanges {
                    log(.error, "Streaming ranges requires the remote HTTP server to support byte range requests: \(url)")
                    task.cancel()
                    return .failure(.rangeNotSupported)
                }

                if let onReceive = onReceiveResponse {
                    let result = await onReceive(httpResponse)
                    if case let .failure(error) = result {
                        task.cancel()
                        return .failure(error)
                    }
                }

                let expectedBytes = httpResponse.resourceLength
                var readBytes: Int64 = httpResponse.contentByteRange?.range?.lowerBound ?? 0

                for try await chunk in stream {
                    try Task.checkCancellation()
                    readBytes += Int64(chunk.count)
                    let progress = expectedBytes.map { $0 > 0 ? Double(min(readBytes, $0)) / Double($0) : 1.0 }
                    if case let .failure(error) = consume(chunk, progress) {
                        task.cancel()
                        return .failure(error)
                    }
                }

                try Task.checkCancellation()
                return .success(httpResponse)
            } onCancel: {
                task.cancel()
            }

        } catch {
            if (error is CancellationError) || ((error as? URLError)?.code == .cancelled) {
                return .failure(.cancelled)
            }
            return .failure(.wrap(error) ?? .other(error))
        }
    }

    private let maxErrorBodySize = 1024 * 1024

    private func collectErrorBody(
        from stream: AsyncThrowingStream<Data, Error>,
        task: URLSessionDataTask
    ) async throws -> Data {
        var data = Data()
        for try await chunk in stream {
            data.append(chunk)
            if data.count >= maxErrorBodySize {
                task.cancel()
                break
            }
        }
        return data.prefix(maxErrorBodySize)
    }

    private func makeURLRequest(_ request: HTTPRequest) -> URLRequest {
        var urlRequest = URLRequest(url: request.url.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.allHTTPHeaderFields = request.headers
        urlRequest.timeoutInterval = request.timeoutInterval ?? session.configuration.timeoutIntervalForRequest

        if let body = request.body {
            switch body {
            case let .data(data):
                urlRequest.httpBody = data
            case let .file(url):
                urlRequest.httpBodyStream = InputStream(url: url)
            }
        }

        return urlRequest
    }

    private func makeHTTPResponse(request: HTTPRequest, response: HTTPURLResponse, url: HTTPURL) -> HTTPResponse {
        var headers: [String: String] = [:]
        for (k, v) in response.allHeaderFields {
            if let ks = k as? String, let vs = v as? String {
                headers[ks] = vs
            }
        }
        return HTTPResponse(
            request: request,
            url: url,
            status: HTTPStatus(rawValue: response.statusCode),
            headers: headers,
            mediaType: response.mimeType.flatMap { MediaType($0) }
        )
    }

    private func makeErrorResponse(httpResponse: HTTPResponse, body: Data) -> HTTPErrorResponse {
        HTTPErrorResponse(
            status: httpResponse.status,
            body: body,
            mediaType: httpResponse.mediaType,
            headers: httpResponse.headers
        )
    }

    /// Lets the `delegate` customize the `request` if needed, before actually starting it.
    private func willStartRequest(_ request: HTTPRequest) async -> HTTPResult<HTTPRequest> {
        guard let delegate else {
            return .success(request)
        }
        return await delegate.httpClient(self, willStartRequest: request)
            .flatMap { $0.httpRequest() }
    }

    /// Attempts to recover from an `error` by asking the `delegate` for a new request.
    private func recover(_ request: HTTPRequest, from error: HTTPError) async -> HTTPResult<HTTPRequestConvertible> {
        if let delegate {
            return await delegate.httpClient(self, recoverRequest: request, fromError: error)
        } else {
            return .failure(error)
        }
    }

    /// Minimal `URLSessionDataDelegate` that handles auth challenges and
    /// bridges data callbacks into `AsyncThrowingStream`.
    private final class TaskDelegate: NSObject, URLSessionDataDelegate, Sendable {
        let request: HTTPRequest

        /// Strong reference — the delegate must remain alive for the full
        /// lifetime of the request (auth challenges, response notifications).
        let delegate: (any DefaultHTTPClientDelegate)?

        private struct WeakClient: Sendable {
            weak var value: DefaultHTTPClient?
        }

        private let _client: Mutex<WeakClient>
        var client: DefaultHTTPClient? {
            _client.withLock { $0.value }
        }

        private struct State: Sendable {
            var authTask: Task<Void, Never>?
            var streamContinuation: AsyncThrowingStream<Data, Error>.Continuation?
            var responseContinuation: CheckedContinuation<(AsyncThrowingStream<Data, Error>, URLResponse), Error>?
        }

        private let state = Mutex(State())

        init(
            request: HTTPRequest,
            delegate: (any DefaultHTTPClientDelegate)?,
            client: DefaultHTTPClient
        ) {
            self.request = request
            self.delegate = delegate
            _client = Mutex(WeakClient(value: client))
        }

        func setResponseContinuation(_ continuation: CheckedContinuation<(AsyncThrowingStream<Data, Error>, URLResponse), Error>) {
            state.withLock { $0.responseContinuation = continuation }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            let (authTask, responseCont, streamCont) = state.withLock { s in
                let auth = s.authTask
                s.authTask = nil
                let resp = s.responseContinuation
                s.responseContinuation = nil
                let stream = s.streamContinuation
                return (auth, resp, stream)
            }

            authTask?.cancel()

            if let responseCont {
                if let error {
                    responseCont.resume(throwing: error)
                } else {
                    responseCont.resume(throwing: URLError(.badServerResponse))
                }
            } else {
                if let error {
                    streamCont?.finish(throwing: error)
                } else {
                    streamCont?.finish()
                }
            }
        }

        func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            didReceive response: URLResponse
        ) async -> URLSession.ResponseDisposition {
            let responseCont = state.withLock { s in
                let cont = s.responseContinuation
                s.responseContinuation = nil
                return cont
            }

            if let responseCont {
                var streamContinuation: AsyncThrowingStream<Data, Error>.Continuation!
                let stream = AsyncThrowingStream<Data, Error> { cont in
                    streamContinuation = cont
                }
                state.withLock { $0.streamContinuation = streamContinuation }
                responseCont.resume(returning: (stream, response))
                return .allow
            } else {
                return .cancel
            }
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            let cont = state.withLock { $0.streamContinuation }
            cont?.yield(data)
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            guard let client = client else {
                completionHandler(.performDefaultHandling, nil)
                return
            }

            state.withLock { s in
                s.authTask?.cancel()
                s.authTask = Task {
                    if Task.isCancelled {
                        completionHandler(.cancelAuthenticationChallenge, nil)
                        return
                    }

                    if let delegate {
                        let response = await delegate.httpClient(client, request: request, didReceive: challenge)

                        if Task.isCancelled {
                            completionHandler(.cancelAuthenticationChallenge, nil)
                            return
                        }

                        switch response {
                        case let .useCredential(credential):
                            completionHandler(.useCredential, credential)
                        case .performDefaultHandling:
                            completionHandler(.performDefaultHandling, nil)
                        case .cancelAuthenticationChallenge:
                            completionHandler(.cancelAuthenticationChallenge, nil)
                        case .rejectProtectionSpace:
                            completionHandler(.rejectProtectionSpace, nil)
                        }
                    } else {
                        completionHandler(.performDefaultHandling, nil)
                    }
                }
            }
        }
    }
}
