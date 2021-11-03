//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

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

}

public extension DefaultHTTPClientDelegate {

    func httpClient(_ httpClient: DefaultHTTPClient, willStartRequest request: HTTPRequest, completion: @escaping (HTTPResult<HTTPRequestConvertible>) -> ()) {
        completion(.success(request))
    }

    func httpClient(_ httpClient: DefaultHTTPClient, recoverRequest request: HTTPRequest, fromError error: HTTPError, completion: @escaping (HTTPResult<HTTPRequestConvertible>) -> ()) {
        completion(.failure(error))
    }

    func httpClient(_ httpClient: DefaultHTTPClient, request: HTTPRequest, didReceiveResponse response: HTTPResponse) {}
    func httpClient(_ httpClient: DefaultHTTPClient, request: HTTPRequest, didFailWithError error: HTTPError) {}

}

/// An implementation of `HTTPClient` using native APIs.
public final class DefaultHTTPClient: NSObject, HTTPClient, Loggable, URLSessionDataDelegate {

    /// Creates a `DefaultHTTPClient` with common configuration settings.
    ///
    /// - Parameters:
    ///   - cachePolicy: Determines the request caching policy used by HTTP tasks.
    ///   - ephemeral: When true, uses no persistent storage for caches, cookies, or credentials.
    ///   - additionalHeaders: A dictionary of additional headers to send with requests. For example, `User-Agent`.
    ///   - requestTimeout: The timeout interval to use when waiting for additional data.
    ///   - resourceTimeout: The maximum amount of time that a resource request should be allowed to take.
    ///   - configure: Callback used to configure further the `URLSessionConfiguration` object.
    public convenience init(
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

        self.init(configuration: config, delegate: delegate)
    }

    /// Creates a `DefaultHTTPClient` with a custom configuration.
    public init(configuration: URLSessionConfiguration, delegate: DefaultHTTPClientDelegate? = nil) {
        super.init()
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.delegate = delegate
    }

    public weak var delegate: DefaultHTTPClientDelegate? = nil

    private var session: URLSession!

    deinit {
        session.invalidateAndCancel()
    }

    public func stream(_ request: HTTPRequestConvertible, receiveResponse: ((HTTPResponse) -> ())?, consume: @escaping (Data, Double?) -> (), completion: @escaping (HTTPResult<HTTPResponse>) -> ()) -> Cancellable {
        let mediator = MediatorCancellable()

        /// Attempts to start a `request`.
        /// Will try to recover from errors using the `delegate` and calling itself again.
        func tryStart(_ request: HTTPRequestConvertible) -> HTTPDeferred<HTTPResponse> {
            request.httpRequest().deferred
                .flatMap(willStartRequest)
                .flatMap(requireNotCancelled)
                .flatMap { request in
                    return startTask(for: request)
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
                let cancellable = self.start(Task(
                    request: request,
                    task: self.session.dataTask(with: request.urlRequest),
                    receiveResponse: { [weak self] response in
                        if let self = self {
                            self.delegate?.httpClient(self, request: request, didReceiveResponse: response)
                        }
                        receiveResponse?(response)
                    },
                    consume: consume,
                    completion: { [weak self] result in
                        if let self = self, case .failure(let error) = result {
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


    // MARK: - Task Management

    /// On-going tasks.
    private var tasks: [Task] = []

    private func findTaskIndex(_ task: URLSessionTask) -> Int? {
        let i = tasks.firstIndex(where: { $0.task == task})
        if i == nil {
            log(.error, "Cannot find on-going HTTP task for \(task)")
        }
        return i
    }

    private func start(_ task: Task) -> Cancellable {
        tasks.append(task)
        task.start()
        return task
    }


    // MARK: - URLSessionDataDelegate

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> ()) {
        guard let i = findTaskIndex(dataTask) else {
            completionHandler(.cancel)
            return
        }
        tasks[i].urlSession(session, didReceive: response, completionHandler: completionHandler)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let i = findTaskIndex(dataTask) else {
            return
        }
        tasks[i].urlSession(session, didReceive: data)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let i = findTaskIndex(task) else {
            return
        }
        tasks[i].urlSession(session, didCompleteWithError: error)
    }


    /// Represents an on-going HTTP task.
    private class Task: Cancellable, Loggable {

        enum TaskError: Error {
            case byteRangesNotSupported(url: URL)
        }

        private let request: HTTPRequest
        fileprivate let task: URLSessionTask
        private let receiveResponse: ((HTTPResponse) -> Void)
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

        init(request: HTTPRequest, task: URLSessionDataTask, receiveResponse: @escaping ((HTTPResponse) -> Void), consume: @escaping (Data, Double?) -> Void, completion: @escaping (HTTPResult<HTTPResponse>) -> Void) {
            self.request = request
            self.task = task
            self.completion = completion
            self.receiveResponse = receiveResponse
            self.consume = consume
        }

        func start() {
            self.log(.info, request)
            task.resume()
        }

        func cancel() {
            task.cancel()
        }

        private func finish() {
            switch state {
            case .start:
                preconditionFailure("finish() called in `start` state")

            case .stream(let response, _):
                completion(.success(response))

            case .failure(let kind, let cause, let response):
                let error = HTTPError(kind: kind, cause: cause, response: response)
                log(.error, "\(request.method) \(request.url) failed with: \(error.localizedDescription)")
                completion(.failure(error))

            case .finished:
                break
            }

            state = .finished
        }

        func urlSession(_ session: URLSession, didReceive urlResponse: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> ()) {
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

            var response = HTTPResponse(response: urlResponse, url: url)

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
                // FIXME: Use task.progress.fractionCompleted once we bump minimum iOS version to 11+
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
            case .data(let data):
                request.httpBody = data
            case .file(let url):
                request.httpBodyStream = InputStream(url: url)
            }
        }

        return request
    }

}
