//
//  Copyright 2024 Readium Foundation. All rights reserved.
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
    func httpClient(_ httpClient: DefaultHTTPClient, willStartRequest request: HTTPRequest, completion: @escaping (HTTPResult<HTTPRequestConvertible>) -> Void)

    /// Asks the delegate to recover from an `error` received for the given `request`.
    ///
    /// This can be used to implement custom authentication flows, for example.
    ///
    /// You can call the `completion` handler with either:
    ///   * a new request to start
    ///   * the `error` argument, if you cannot recover from it
    ///   * a new `HTTPError` to provide additional information
    func httpClient(_ httpClient: DefaultHTTPClient, recoverRequest request: HTTPRequest, fromError error: HTTPError, completion: @escaping (HTTPResult<HTTPRequestConvertible>) -> Void)

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
        didReceive challenge: URLAuthenticationChallenge,
        completion: @escaping (URLAuthenticationChallengeResponse) -> Void
    )
}

public extension DefaultHTTPClientDelegate {
    func httpClient(_ httpClient: DefaultHTTPClient, willStartRequest request: HTTPRequest, completion: @escaping (HTTPResult<HTTPRequestConvertible>) -> Void) {
        completion(.success(request))
    }

    func httpClient(_ httpClient: DefaultHTTPClient, recoverRequest request: HTTPRequest, fromError error: HTTPError, completion: @escaping (HTTPResult<HTTPRequestConvertible>) -> Void) {
        completion(.failure(error))
    }

    func httpClient(_ httpClient: DefaultHTTPClient, request: HTTPRequest, didReceiveResponse response: HTTPResponse) {}
    func httpClient(_ httpClient: DefaultHTTPClient, request: HTTPRequest, didFailWithError error: HTTPError) {}

    func httpClient(
        _ httpClient: DefaultHTTPClient,
        request: HTTPRequest,
        didReceive challenge: URLAuthenticationChallenge,
        completion: @escaping (URLAuthenticationChallengeResponse) -> Void
    ) {
        completion(.performDefaultHandling)
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

    private let tasks: TaskManager
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
        let tasks = TaskManager()

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

    public func stream(_ request: HTTPRequestConvertible, receiveResponse: ((HTTPResponse) -> Void)?, consume: @escaping (Data, Double?) -> Void, completion: @escaping (HTTPResult<HTTPResponse>) -> Void) -> Cancellable {
        let mediator = MediatorCancellable()

        /// Attempts to start a `request`.
        /// Will try to recover from errors using the `delegate` and calling itself again.
        func tryStart(_ request: HTTPRequestConvertible) -> HTTPDeferred<HTTPResponse> {
            request.httpRequest().deferred
                .flatMap(willStartRequest)
                .flatMap(requireNotCancelled)
                .flatMap { request in
                    startTask(for: request)
                        .flatCatch { error in
                            recoverRequest(request, fromError: error)
                                .flatMap(requireNotCancelled)
                                .flatMap { newRequest in
                                    tryStart(newRequest)
                                }
                        }
                }
        }

        /// Will interrupt the flow if the `mediator` received a cancel request.
        func requireNotCancelled<T>(_ value: T) -> HTTPDeferred<T> {
            if mediator.isCancelled {
                return .failure(HTTPError(kind: .cancelled))
            } else {
                return .success(value)
            }
        }

        /// Creates and starts a new task for the `request`, whose cancellable will be exposed through `mediator`.
        func startTask(for request: HTTPRequest) -> HTTPDeferred<HTTPResponse> {
            deferred { completion in
                var request = request
                if request.userAgent == nil {
                    request.userAgent = self.userAgent
                }

                let cancellable = self.tasks.start(Task(
                    request: request,
                    task: self.session.dataTask(with: request.urlRequest),
                    receiveResponse: { [weak self] response in
                        if let self = self {
                            self.delegate?.httpClient(self, request: request, didReceiveResponse: response)
                        }
                        receiveResponse?(response)
                    },
                    receiveChallenge: { [weak self] challenge, completion in
                        if let self = self, let delegate = self.delegate {
                            delegate.httpClient(self, request: request, didReceive: challenge, completion: completion)
                        } else {
                            completion(.performDefaultHandling)
                        }
                    },
                    consume: consume,
                    completion: { [weak self] result in
                        if let self = self, case let .failure(error) = result {
                            self.delegate?.httpClient(self, request: request, didFailWithError: error)
                        }
                        completion(CancellableResult(result))
                    }
                ))

                mediator.mediate(cancellable)
            }
        }

        /// Lets the `delegate` customize the `request` if needed, before actually starting it.
        func willStartRequest(_ request: HTTPRequest) -> HTTPDeferred<HTTPRequest> {
            deferred { completion in
                if let delegate = self.delegate {
                    delegate.httpClient(self, willStartRequest: request) { result in
                        let request = result.flatMap { $0.httpRequest() }
                        completion(CancellableResult(request))
                    }
                } else {
                    completion(.success(request))
                }
            }
        }

        /// Attempts to recover from a `error` by asking the `delegate` for a new request.
        func recoverRequest(_ request: HTTPRequest, fromError error: HTTPError) -> HTTPDeferred<HTTPRequestConvertible> {
            deferred { completion in
                if let delegate = self.delegate {
                    delegate.httpClient(self, recoverRequest: request, fromError: error) { completion(CancellableResult($0)) }
                } else {
                    completion(.failure(error))
                }
            }
        }

        tryStart(request)
            .resolve(on: .main) { result in
                // Convert a `CancellableResult` to an `HTTPResult`, as expected by the `completion` handler.
                let result = result.result(withCancelledError: HTTPError(kind: .cancelled))
                completion(result)
            }

        return mediator
    }

    private class TaskManager: NSObject, URLSessionDataDelegate {
        /// On-going tasks.
        @Atomic private var tasks: [Task] = []

        func start(_ task: Task) -> Cancellable {
            $tasks.write { $0.append(task) }
            task.start()
            return task
        }

        private func findTask(for urlTask: URLSessionTask) -> Task? {
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
    private class Task: Cancellable, Loggable {
        enum TaskError: Error {
            case byteRangesNotSupported(url: URL)
        }

        private let request: HTTPRequest
        fileprivate let task: URLSessionTask
        private let receiveResponse: (HTTPResponse) -> Void
        private let receiveChallenge: (URLAuthenticationChallenge, @escaping (URLAuthenticationChallengeResponse) -> Void) -> Void
        private let consume: (Data, Double?) -> Void
        private let completion: (HTTPResult<HTTPResponse>) -> Void

        /// States the HTTP task can be in.
        private var state: State = .start

        private enum State {
            /// Waiting for the HTTP response.
            case start
            /// We received a success response, the data will be sent to `consume` progressively.
            case stream(HTTPResponse, readBytes: Int64)
            /// We received an error response, the data will be accumulated in `response.body` to make the final
            /// `HTTPError`. The body is needed for example when the response is an OPDS Authentication Document.
            case failure(kind: HTTPError.Kind, cause: Error?, response: HTTPResponse?)
            /// The request is terminated.
            case finished
        }

        init(
            request: HTTPRequest,
            task: URLSessionDataTask,
            receiveResponse: @escaping (HTTPResponse) -> Void,
            receiveChallenge: @escaping (URLAuthenticationChallenge, @escaping (URLAuthenticationChallengeResponse) -> Void) -> Void,
            consume: @escaping (Data, Double?) -> Void,
            completion: @escaping (HTTPResult<HTTPResponse>) -> Void
        ) {
            self.request = request
            self.task = task
            self.completion = completion
            self.receiveResponse = receiveResponse
            self.receiveChallenge = receiveChallenge
            self.consume = consume
        }

        func start() {
            log(.info, request)
            task.resume()
        }

        func cancel() {
            task.cancel()
        }

        private func finish() {
            switch state {
            case .start:
                preconditionFailure("finish() called in `start` state")

            case let .stream(response, _):
                completion(.success(response))

            case let .failure(kind, cause, response):
                let error = HTTPError(kind: kind, cause: cause, response: response)
                log(.error, "\(request.method) \(request.url) failed with: \(error.localizedDescription)")
                completion(.failure(error))

            case .finished:
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
                let urlResponse = urlResponse as? HTTPURLResponse,
                let url = urlResponse.url
            else {
                completionHandler(.cancel)
                return
            }

            var response = HTTPResponse(request: request, response: urlResponse, url: url)

            if let kind = HTTPError.Kind(statusCode: response.statusCode) {
                state = .failure(kind: kind, cause: nil, response: response)

                // It was a HEAD request? We need to query the resource again to get the error body. The body is needed
                // for example when the response is an OPDS Authentication Document.
                if request.method == .head {
                    var modifiedRequest = request
                    modifiedRequest.method = .get
                    session.dataTask(with: modifiedRequest.urlRequest) { data, _, error in
                        response.body = data
                        self.state = .failure(kind: kind, cause: error, response: response)
                        completionHandler(.cancel)
                    }.resume()
                    return
                }

            } else {
                guard !request.hasHeader("Range") || response.acceptsByteRanges else {
                    log(.error, "Streaming ranges requires the remote HTTP server to support byte range requests: \(url)")
                    state = .failure(kind: .other, cause: TaskError.byteRangesNotSupported(url: url), response: response)
                    completionHandler(.cancel)
                    return
                }

                state = .stream(response, readBytes: 0)
                receiveResponse(response)
            }

            completionHandler(.allow)
        }

        func urlSession(_ session: URLSession, didReceive data: Data) {
            switch state {
            case .start, .finished:
                break

            case .stream(let response, var readBytes):
                readBytes += Int64(data.count)
                var progress: Double? = nil
                if let expectedBytes = response.contentLength {
                    progress = Double(min(readBytes, expectedBytes)) / Double(expectedBytes)
                }
                consume(data, progress)
                state = .stream(response, readBytes: readBytes)

            case .failure(let kind, let cause, var response):
                var body = response?.body ?? Data()
                body.append(data)
                response?.body = body
                state = .failure(kind: kind, cause: cause, response: response)
            }
        }

        func urlSession(_ session: URLSession, didCompleteWithError error: Error?) {
            if let error = error {
                if case .failure = state {
                    // No-op, we don't want to overwrite the failure state in this case.
                } else {
                    state = .failure(kind: HTTPError.Kind(error: error), cause: error, response: nil)
                }
            }
            finish()
        }

        func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completion: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            receiveChallenge(challenge) { response in
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

private extension HTTPRequest {
    var urlRequest: URLRequest {
        var request = URLRequest(url: url)
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
