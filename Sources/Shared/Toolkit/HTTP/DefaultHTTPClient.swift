//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

public enum URLAuthenticationChallengeResponse: Sendable     {
    /// Use the specified credential.
    case useCredential(URLCredential)
    /// Use the default handling for the challenge as though this delegate method were not implemented.
    case performDefaultHandling
    /// Cancel the entire request.
    case cancelAuthenticationChallenge
    /// Reject this challenge, and call the authentication delegate method again with the next
    /// authentication protection space.
    case rejectProtectionSpace
}

/// Delegate protocol for `DefaultHTTPClient`.
public protocol DefaultHTTPClientDelegate: AnyObject, Sendable {
    /// Tells the delegate that the HTTP client will start a new `request`.
    ///
    /// Warning: You MUST call the `completion` handler with the request to start, otherwise the client will hang.
    ///
    /// You can modify the `request`, for example by adding additional HTTP headers or redirecting to a different URL,
    /// before calling the `completion` handler with the new request.
    func httpClient(_ httpClient: DefaultHTTPClient, willStartRequest request: HTTPRequest) async -> HTTPResult<HTTPRequestConvertible>

    /// Asks the delegate to recover from an `error` received for the given `request`.
    ///
    /// This can be used to implement custom authentication flows, for example.
    ///
    /// You can call the `completion` handler with either:
    ///   * a new request to start
    ///   * the `error` argument, if you cannot recover from it
    ///   * a new `HTTPError` to provide additional information
    func httpClient(_ httpClient: DefaultHTTPClient, recoverRequest request: HTTPRequest, fromError error: HTTPError) async -> HTTPResult<HTTPRequestConvertible>

    /// Tells the delegate that we received an HTTP response for the given `request`.
    ///
    /// You do not need to do anything with this `response`, which the HTTP client will handle. This is merely for
    /// informational purposes. For example, you could implement this to confirm that request credentials were
    /// successful.
    func httpClient(_ httpClient: DefaultHTTPClient, request: HTTPRequest, didReceiveResponse response: HTTPResponse) async

    /// Tells the delegate that a `request` failed with the given `error`.
    ///
    /// You do not need to do anything with this `response`, which the HTTP client will handle. This is merely for
    /// informational purposes.
    ///
    /// This will be called only if `httpClient(_:recoverRequest:fromError:completion:)` is not implemented, or returns
    /// an error.
    func httpClient(_ httpClient: DefaultHTTPClient, request: HTTPRequest, didFailWithError error: HTTPError) async

    /// Requests credentials from the delegate in response to an authentication request from the remote server.
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

    func httpClient(_ httpClient: DefaultHTTPClient, request: HTTPRequest, didReceiveResponse response: HTTPResponse) async {}
    func httpClient(_ httpClient: DefaultHTTPClient, request: HTTPRequest, didFailWithError error: HTTPError) async {}

    func httpClient(
        _ httpClient: DefaultHTTPClient,
        request: HTTPRequest,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> URLAuthenticationChallengeResponse {
        .performDefaultHandling
    }
}

/// An implementation of `HTTPClient` using native APIs.
public final actor DefaultHTTPClient: HTTPClient, Loggable {
    /// Returns the default user agent used when issuing requests.
    ///
    /// For example, TestApp/1.3 x86_64 iOS/15.0 CFNetwork/1312 Darwin/20.6.0
    public static let defaultUserAgent: String = {
        var sysinfo = utsname()
        uname(&sysinfo)

        let darwinVersion = String(bytes: Data(bytes: &sysinfo.release, count: Int(_SYS_NAMELEN)), encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            ?? "0"

        let deviceName = String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            ?? "0"

        let cfNetworkVersion = Bundle(identifier: "com.apple.CFNetwork")?
            .infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "0"

        let appInfo = Bundle.main.infoDictionary
        let appName = appInfo?["CFBundleName"] as? String ?? "Unknown App"
        let appVersion = appInfo?["CFBundleShortVersionString"] as? String ?? "0"

        let deviceSystemName: String
        let deviceSystemVersion: String
        if Thread.isMainThread {
            (deviceSystemName, deviceSystemVersion) = MainActor.assumeIsolated {
                let device = UIDevice.current
                return (device.systemName, device.systemVersion)
            }
        } else {
            deviceSystemName = "iOS"
            deviceSystemVersion = "0.0"
        }

        return "\(appName)/\(appVersion) \(deviceName) \(deviceSystemName)/\(deviceSystemVersion) CFNetwork/\(cfNetworkVersion) Darwin/\(darwinVersion)"
    }()

    /// Creates a `DefaultHTTPClient` with common configuration settings.
    ///
    /// - Parameters:
    ///   - userAgent: Default user agent issued with requests.
    ///   - cachePolicy: Determines the request caching policy used by HTTP tasks.
    ///   - ephemeral: When true, uses no persistent storage for caches, cookies, or credentials.
    ///   - additionalHeaders: A dictionary of additional headers to send with requests. For example, `User-Agent`.
    ///   - requestTimeout: The timeout interval to use when waiting for additional data.
    ///   - resourceTimeout: The maximum amount of time that a resource request should be allowed to take.
    ///   - configure: Callback used to configure further the `URLSessionConfiguration` object.
    public init(
        userAgent: String? = nil,
        cachePolicy: URLRequest.CachePolicy? = nil,
        ephemeral: Bool = false,
        additionalHeaders: [String: String]? = nil,
        requestTimeout: TimeInterval? = nil,
        resourceTimeout: TimeInterval? = nil,
        delegate: DefaultHTTPClientDelegate? = nil,
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

    public var delegate: DefaultHTTPClientDelegate? {
        get { _delegate.ref as? DefaultHTTPClientDelegate }
        set { _delegate.ref = newValue }
    }

    private let _delegate: Weak<AnyObject>

    private let tasks: HTTPTaskManager
    private let session: URLSession
    private let userAgent: String

    /// Creates a `DefaultHTTPClient` with a custom configuration.
    ///
    /// - Parameters:
    ///   - userAgent: Default user agent issued with requests.
    public init(
        configuration: URLSessionConfiguration,
        userAgent: String? = nil,
        delegate: DefaultHTTPClientDelegate? = nil
    ) {
        let tasks = HTTPTaskManager()

        self.userAgent = userAgent ?? DefaultHTTPClient.defaultUserAgent
        _delegate = Weak(delegate as AnyObject?)
        self.tasks = tasks
        // Note that URLSession keeps a strong reference to its delegate, so we
        // don't use the DefaultHTTPClient itself as its delegate.
        session = URLSession(configuration: configuration, delegate: tasks, delegateQueue: nil)
    }

    deinit {
        session.invalidateAndCancel()
    }

    public func stream(
        request: any HTTPRequestConvertible,
        consume: @escaping @Sendable (Data, Double?) async -> HTTPResult<Void>
    ) async -> HTTPResult<HTTPResponse> {
        var result = request.httpRequest()

        switch result {
        case let .success(httpRequest):
            result = await willStartRequest(httpRequest)
        case .failure:
            return result.map { _ in fatalError("unreachable") }
        }

        let httpRequest: HTTPRequest
        switch result {
        case let .success(request):
            httpRequest = request
        case let .failure(error):
            return .failure(error)
        }

        let taskResult = await startTask(for: httpRequest, consume: consume)

        switch taskResult {
        case .success:
            return taskResult
        case let .failure(error):
            let recoveryResult = await recover(httpRequest, from: error)

            switch recoveryResult {
            case let .success(newRequest):
                return await stream(request: newRequest, consume: consume)
            case let .failure(recoveryError):
                return .failure(recoveryError)
            }
        }
    }

    /// Creates and starts a new task for the `request`, whose cancellable will be exposed through `mediator`.
    private func startTask(for request: HTTPRequest, consume: @escaping HTTPTask.Consume) async -> HTTPResult<HTTPResponse> {
        var request = request
        if request.userAgent == nil {
            request.userAgent = userAgent
        }

        let delegate = delegate

        return await withTaskCancellationHandler {
            let stream = AsyncStream<HTTPTask.Event> { continuation in
                let urlRequest = request.urlRequest
                let task = session.dataTask(with: urlRequest)

                tasks.register(task, continuation: continuation)

                task.resume()

                continuation.onTermination = { [weak tasks] _ in
                    tasks?.unregister(task)
                    task.cancel()
                }
            }

            let task = HTTPTask(
                request: request,
                client: self,
                delegate: delegate,
                consume: consume
            )

            return await task.run(with: stream)

        } onCancel: {
            // Cancellation is handled by AsyncStream.onTermination
        }
    }

    /// Lets the `delegate` customize the `request` if needed, before actually starting it.
    private func willStartRequest(_ request: HTTPRequest) async -> HTTPResult<HTTPRequest> {
        guard let delegate = delegate else {
            return .success(request)
        }
        return await delegate.httpClient(self, willStartRequest: request)
            .flatMap { $0.httpRequest() }
    }

    /// Attempts to recover from a `error` by asking the `delegate` for a new request.
    private func recover(_ request: HTTPRequest, from error: HTTPError) async -> HTTPResult<HTTPRequestConvertible> {
        if let delegate = delegate {
            return await delegate.httpClient(self, recoverRequest: request, fromError: error)
        } else {
            return .failure(error)
        }
    }

    private class HTTPTaskManager: NSObject, URLSessionDataDelegate, @unchecked Sendable {
        /// On-going tasks mapped to their event stream continuation.
        @Atomic private var continuations: [URLSessionTask: AsyncStream<HTTPTask.Event>.Continuation] = [:]

        func register(_ task: URLSessionTask, continuation: AsyncStream<HTTPTask.Event>.Continuation) {
            $continuations.write { $0[task] = continuation }
        }

        func unregister(_ task: URLSessionTask) {
            $continuations.write { $0.removeValue(forKey: task) }
        }

        private func continuation(for task: URLSessionTask) -> AsyncStream<HTTPTask.Event>.Continuation? {
            continuations[task]
        }

        // MARK: - URLSessionDataDelegate

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            guard let continuation = continuation(for: dataTask) else {
                completionHandler(.cancel)
                return
            }
            continuation.yield(.response(response, UncheckedSendable(completionHandler)))
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            guard let continuation = continuation(for: dataTask) else {
                return
            }
            continuation.yield(.data(data))
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            guard let continuation = continuation(for: task) else {
                return
            }
            continuation.yield(.complete(error))
            continuation.finish()
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            guard let continuation = continuation(for: task) else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            continuation.yield(.challenge(challenge, UncheckedSendable(completionHandler)))
        }
    }

    /// Represents an on-going HTTP task.
    private actor HTTPTask: Loggable {
        typealias Consume = @Sendable (Data, Double?) async -> HTTPResult<Void>

        enum Event: Sendable {
            case response(URLResponse, UncheckedSendable<(URLSession.ResponseDisposition) -> Void>)
            case data(Data)
            case complete(Error?)
            case challenge(URLAuthenticationChallenge, UncheckedSendable<(URLSession.AuthChallengeDisposition, URLCredential?) -> Void>)
        }

        private let request: HTTPRequest
        private unowned let client: DefaultHTTPClient
        private weak var delegate: DefaultHTTPClientDelegate?
        private let consume: Consume

        private var response: HTTPResponse?
        private var readBytes: Int64 = 0

        init(
            request: HTTPRequest,
            client: DefaultHTTPClient,
            delegate: DefaultHTTPClientDelegate?,
            consume: @escaping Consume
        ) {
            self.request = request
            self.client = client
            self.delegate = delegate
            self.consume = consume
        }

        func run(with stream: AsyncStream<Event>) async -> HTTPResult<HTTPResponse> {
            log(.info, request)

            var result: HTTPResult<HTTPResponse>?

            for await event in stream {
                switch event {
                case let .response(urlResponse, completion):
                    handleResponse(urlResponse, completion: completion.value)

                case let .data(data):
                    if let error = await handleData(data) {
                        result = .failure(error)
                        return .failure(error)
                    }

                case let .complete(error):
                    result = handleCompletion(error)

                case let .challenge(challenge, completion):
                    await handleChallenge(challenge, completion: completion.value)
                }
            }

            if let result = result {
                return result
            } else {
                return .failure(.cancelled)
            }
        }

        private func handleResponse(_ urlResponse: URLResponse, completion: (URLSession.ResponseDisposition) -> Void) {
            guard
                let urlResponse = urlResponse as? HTTPURLResponse,
                let url = urlResponse.url?.httpURL
            else {
                completion(.cancel)
                return
            }

            let response = HTTPResponse(request: request, response: urlResponse, url: url)

            guard response.status.isSuccess else {
                self.response = response
                completion(.allow)
                return
            }

            guard !request.hasHeader("Range") || response.acceptsByteRanges else {
                log(.error, "Streaming ranges requires the remote HTTP server to support byte range requests: \(url)")
                completion(.cancel)
                return
            }

            self.response = response
            readBytes = 0

            Task {
                await delegate?.httpClient(client, request: request, didReceiveResponse: response)
            }

            completion(.allow)
        }

        private func handleData(_ data: Data) async -> HTTPError? {
            if var response = self.response, !response.status.isSuccess {
                var body = response.body ?? Data()
                body.append(data)
                response.body = body
                self.response = response
                return nil
            }

            guard let response = response else {
                return nil
            }

            readBytes += Int64(data.count)
            var progress: Double? = nil
            if let expectedBytes = response.contentLength {
                progress = Double(min(readBytes, expectedBytes)) / Double(expectedBytes)
            }

            let result = await consume(data, progress)
            switch result {
            case .success:
                return nil
            case let .failure(error):
                return error
            }
        }

        private func handleCompletion(_ error: Error?) -> HTTPResult<HTTPResponse> {
            if let error = error {
                let httpError = HTTPError(error: error)
                Task {
                    await delegate?.httpClient(client, request: request, didFailWithError: httpError)
                }
                return .failure(httpError)
            } else if let response = response, !response.status.isSuccess {
                let error = HTTPError.errorResponse(response)
                Task {
                    await delegate?.httpClient(client, request: request, didFailWithError: error)
                }
                return .failure(error)
            } else if let response = response {
                return .success(response)
            } else {
                return .failure(.cancelled)
            }
        }

        private func handleChallenge(_ challenge: URLAuthenticationChallenge, completion: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) async {
            let response: URLAuthenticationChallengeResponse
            if let delegate = delegate {
                response = await delegate.httpClient(client, request: request, didReceive: challenge)
            } else {
                response = .performDefaultHandling
            }

            switch response {
            case let .useCredential(credential):
                completion(.useCredential, credential)
            case .performDefaultHandling:
                completion(.performDefaultHandling, nil)
            case .cancelAuthenticationChallenge:
                completion(.cancelAuthenticationChallenge, nil)
            case .rejectProtectionSpace:
                completion(.rejectProtectionSpace, nil)
            }
        }
    }
}

private extension HTTPResponse {
    init(request: HTTPRequest, response: HTTPURLResponse, url: HTTPURL, body: Data? = nil) {
        var headers: [String: String] = [:]
        for (k, v) in response.allHeaderFields {
            if let ks = k as? String, let vs = v as? String {
                headers[ks] = vs
            }
        }
        self.init(
            request: request,
            url: url,
            status: HTTPStatus(rawValue: response.statusCode),
            headers: headers,
            mediaType: response.mimeType.flatMap { MediaType($0) },
            body: body
        )
    }
}

private extension HTTPError {
    /// Maps a native `URLError` to `HTTPError`.
    init(error: Error) {
        switch error {
        case let error as URLError:
            switch error.code {
            case .httpTooManyRedirects, .redirectToNonExistentLocation:
                self = .redirection(error)
            case .secureConnectionFailed, .clientCertificateRejected, .clientCertificateRequired, .appTransportSecurityRequiresSecureConnection, .userAuthenticationRequired:
                self = .security(error)
            case .badServerResponse, .zeroByteResource, .cannotDecodeContentData, .cannotDecodeRawData, .dataLengthExceedsMaximum:
                self = .malformedResponse(error)
            case .notConnectedToInternet, .networkConnectionLost:
                self = .offline(error)
            case .cannotConnectToHost, .cannotFindHost:
                self = .unreachable(error)
            case .timedOut:
                self = .timeout(error)
            case .cancelled, .userCancelledAuthentication:
                self = .cancelled
            default:
                self = .other(error)
            }
        default:
            self = .other(error)
        }
    }
}

private extension HTTPRequest {
    var urlRequest: URLRequest {
        var request = URLRequest(url: url.url)
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = headers

        if let timeoutInterval = timeoutInterval {
            request.timeoutInterval = timeoutInterval
        }

        if let body = body {
            switch body {
            case let .data(data):
                request.httpBody = data
            case let .file(url):
                request.httpBodyStream = InputStream(url: url)
            }
        }

        return request
    }
}
