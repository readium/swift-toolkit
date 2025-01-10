//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

public enum URLAuthenticationChallengeResponse {
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
public protocol DefaultHTTPClientDelegate: AnyObject {
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
    func httpClient(_ httpClient: DefaultHTTPClient, request: HTTPRequest, didReceiveResponse response: HTTPResponse)

    /// Tells the delegate that a `request` failed with the given `error`.
    ///
    /// You do not need to do anything with this `response`, which the HTTP client will handle. This is merely for
    /// informational purposes.
    ///
    /// This will be called only if `httpClient(_:recoverRequest:fromError:completion:)` is not implemented, or returns
    /// an error.
    func httpClient(_ httpClient: DefaultHTTPClient, request: HTTPRequest, didFailWithError error: HTTPError)

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

/// An implementation of `HTTPClient` using native APIs.
public final class DefaultHTTPClient: HTTPClient, Loggable {
    /// Returns the default user agent used when issuing requests.
    ///
    /// For example, TestApp/1.3 x86_64 iOS/15.0 CFNetwork/1312 Darwin/20.6.0
    public static var defaultUserAgent: String = {
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
        let device = UIDevice.current

        return "\(appName)/\(appVersion) \(deviceName) \(device.systemName)/\(device.systemVersion) CFNetwork/\(cfNetworkVersion) Darwin/\(darwinVersion)"
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
    public convenience init(
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

    public weak var delegate: DefaultHTTPClientDelegate? = nil

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
        self.delegate = delegate
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
        consume: @escaping (Data, Double?) -> HTTPResult<Void>
    ) async -> HTTPResult<HTTPResponse> {
        await request.httpRequest()
            .asyncFlatMap(willStartRequest)
            .asyncFlatMap { request in
                await startTask(for: request, consume: consume)
                    .asyncRecover { error in
                        await recover(request, from: error)
                            .asyncFlatMap { newRequest in
                                await stream(request: newRequest, consume: consume)
                            }
                    }
            }
    }

    /// Creates and starts a new task for the `request`, whose cancellable will be exposed through `mediator`.
    private func startTask(for request: HTTPRequest, consume: @escaping HTTPTask.Consume) async -> HTTPResult<HTTPResponse> {
        var request = request
        if request.userAgent == nil {
            request.userAgent = userAgent
        }

        let result = await tasks.start(
            request: request,
            task: session.dataTask(with: request.urlRequest),
            receiveResponse: { [weak self] response in
                if let self = self {
                    self.delegate?.httpClient(self, request: request, didReceiveResponse: response)
                }
            },
            receiveChallenge: { [weak self] challenge in
                if let self = self, let delegate = self.delegate {
                    return await delegate.httpClient(self, request: request, didReceive: challenge)
                } else {
                    return .performDefaultHandling
                }
            },
            consume: consume
        )

        if let delegate = delegate, case let .failure(error) = result {
            delegate.httpClient(self, request: request, didFailWithError: error)
        }

        return result
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

    private class HTTPTaskManager: NSObject, URLSessionDataDelegate {
        /// On-going tasks.
        @Atomic private var tasks: [HTTPTask] = []

        func start(
            request: HTTPRequest,
            task sessionTask: URLSessionDataTask,
            receiveResponse: @escaping HTTPTask.ReceiveResponse,
            receiveChallenge: @escaping HTTPTask.ReceiveChallenge,
            consume: @escaping HTTPTask.Consume
        ) async -> HTTPResult<HTTPResponse> {
            let task = HTTPTask(
                request: request,
                task: sessionTask,
                receiveResponse: receiveResponse,
                receiveChallenge: receiveChallenge,
                consume: consume
            )
            $tasks.write { $0.append(task) }

            let result = await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    task.start(with: continuation)
                }
            } onCancel: {
                task.cancel()
            }

            $tasks.write { $0.removeAll { $0.task == sessionTask } }

            return result
        }

        private func findTask(for urlTask: URLSessionTask) -> HTTPTask? {
            let task = tasks.first { $0.task == urlTask }
            if task == nil {
                log(.error, "Cannot find on-going HTTP task for \(urlTask)")
            }
            return task
        }

        // MARK: - URLSessionDataDelegate

        public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            guard let task = findTask(for: dataTask) else {
                completionHandler(.cancel)
                return
            }
            task.urlSession(session, didReceive: response, completionHandler: completionHandler)
        }

        public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            findTask(for: dataTask)?.urlSession(session, didReceive: data)
        }

        public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            findTask(for: task)?.urlSession(session, didCompleteWithError: error)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            guard let task = findTask(for: task) else {
                completionHandler(.performDefaultHandling, nil)
                return
            }

            task.urlSession(session, didReceive: challenge, completion: completionHandler)
        }
    }

    /// Represents an on-going HTTP task.
    private class HTTPTask: Cancellable, Loggable {
        typealias Continuation = CheckedContinuation<HTTPResult<HTTPResponse>, Never>
        typealias ReceiveResponse = (HTTPResponse) -> Void
        typealias ReceiveChallenge = (URLAuthenticationChallenge) async -> URLAuthenticationChallengeResponse
        typealias Consume = (Data, Double?) -> HTTPResult<Void>

        private let request: HTTPRequest
        fileprivate let task: URLSessionTask
        private let receiveResponse: ReceiveResponse
        private let receiveChallenge: ReceiveChallenge
        private let consume: Consume

        /// States the HTTP task can be in.
        private var state: State = .initializing

        private enum State {
            /// Waiting to start the task.
            case initializing

            /// Waiting for the HTTP response.
            case start(continuation: Continuation)

            /// We received a success response, the data will be sent to
            /// `consume` progressively.
            case stream(continuation: Continuation, response: HTTPResponse, readBytes: Int64)

            /// We received an error response, the data will be accumulated in
            /// `response.body` if the error is an `HTTPError.errorResponse`, as
            /// it could be needed for example when the response is an OPDS
            /// Authentication Document.
            case failure(continuation: Continuation, error: HTTPError)

            /// The request is terminated.
            case finished

            var continuation: Continuation? {
                switch self {
                case .initializing, .finished:
                    return nil
                case let .start(continuation):
                    return continuation
                case let .stream(continuation, _, _):
                    return continuation
                case let .failure(continuation, _):
                    return continuation
                }
            }
        }

        init(
            request: HTTPRequest,
            task: URLSessionDataTask,
            receiveResponse: @escaping ReceiveResponse,
            receiveChallenge: @escaping ReceiveChallenge,
            consume: @escaping Consume
        ) {
            self.request = request
            self.task = task
            self.receiveResponse = receiveResponse
            self.receiveChallenge = receiveChallenge
            self.consume = consume
        }

        deinit {
            finish()
        }

        func start(with continuation: Continuation) {
            log(.info, request)
            state = .start(continuation: continuation)
            task.resume()
        }

        func cancel() {
            task.cancel()
        }

        private func finish() {
            switch state {
            case let .start(continuation):
                continuation.resume(returning: .failure(.cancelled))

            case let .stream(continuation, response, _):
                continuation.resume(returning: .success(response))

            case let .failure(continuation, error):
                var errorDescription = ""
                dump(error, to: &errorDescription)
                log(.error, "\(request.method) \(request.url) failed with:\n\(errorDescription)")
                continuation.resume(returning: .failure(error))

            case .initializing, .finished:
                break
            }

            state = .finished
        }

        func urlSession(_ session: URLSession, didReceive urlResponse: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            if case .finished = state {
                completionHandler(.cancel)
                return
            }
            guard
                let continuation = state.continuation,
                let urlResponse = urlResponse as? HTTPURLResponse,
                let url = urlResponse.url?.httpURL
            else {
                completionHandler(.cancel)
                return
            }

            let response = HTTPResponse(request: request, response: urlResponse, url: url)

            guard response.status.isSuccess else {
                state = .failure(continuation: continuation, error: .errorResponse(response))
                completionHandler(.allow)
                return
            }

            guard !request.hasHeader("Range") || response.acceptsByteRanges else {
                log(.error, "Streaming ranges requires the remote HTTP server to support byte range requests: \(url)")
                state = .failure(continuation: continuation, error: .rangeNotSupported)
                completionHandler(.cancel)
                return
            }

            state = .stream(continuation: continuation, response: response, readBytes: 0)
            receiveResponse(response)

            completionHandler(.allow)
        }

        func urlSession(_ session: URLSession, didReceive data: Data) {
            switch state {
            case .initializing, .start, .finished:
                break

            case .stream(let continuation, let response, var readBytes):
                readBytes += Int64(data.count)
                var progress: Double? = nil
                if let expectedBytes = response.contentLength {
                    progress = Double(min(readBytes, expectedBytes)) / Double(expectedBytes)
                }

                switch consume(data, progress) {
                case .success:
                    state = .stream(continuation: continuation, response: response, readBytes: readBytes)
                case let .failure(error):
                    state = .failure(continuation: continuation, error: error)
                }

            case .failure(let continuation, var error):
                if case var .errorResponse(response) = error {
                    var body = response.body ?? Data()
                    body.append(data)
                    response.body = body
                    error = .errorResponse(response)
                }

                state = .failure(continuation: continuation, error: error)
            }
        }

        func urlSession(_ session: URLSession, didCompleteWithError error: Error?) {
            if let error = error {
                if case .failure = state {
                    // No-op, we don't want to overwrite the failure state in this case.
                } else if let continuation = state.continuation {
                    state = .failure(continuation: continuation, error: HTTPError(error: error))
                } else {
                    state = .finished
                }
            }
            finish()
        }

        func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completion: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            Task {
                let response = await receiveChallenge(challenge)
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
