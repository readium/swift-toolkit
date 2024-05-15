//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumGCDWebServer
import ReadiumShared
import UIKit

public enum GCDHTTPServerError: Error {
    case failedToStartServer(cause: Error)
    case serverNotStarted
    case invalidEndpoint(HTTPServerEndpoint)
    case nullServerURL
}

/// Implementation of `HTTPServer` using ReadiumGCDWebServer under the hood.
public class GCDHTTPServer: HTTPServer, Loggable {
    /// Shared instance of the HTTP server.
    public static let shared = GCDHTTPServer()

    /// The actual underlying HTTP server instance.
    private let server = ReadiumGCDWebServer()

    /// Mapping between endpoints and their handlers.
    private var handlers: [HTTPURL: HTTPRequestHandler] = [:]

    /// Mapping between endpoints and resource transformers.
    private var transformers: [HTTPURL: [ResourceTransformer]] = [:]

    private enum State {
        case stopped
        case started(port: UInt, baseURL: HTTPURL)
    }

    private var state: State = .stopped

    /// Dispatch queue to protect accesses to the handlers, transformers and
    /// state.
    private let queue = DispatchQueue(
        label: "org.readium.swift-toolkit.adapter.gcdwebserver",
        attributes: .concurrent
    )

    /// Creates a new instance of the HTTP server.
    ///
    /// - Parameter logLevel: See `ReadiumGCDWebServer.setLogLevel`.
    public init(logLevel: Int = 3) {
        ReadiumGCDWebServer.setLogLevel(Int32(logLevel))

        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        server.addDefaultHandler(
            forMethod: "GET",
            request: ReadiumGCDWebServerRequest.self,
            asyncProcessBlock: { [weak self] request, completion in
                self?.handle(request: request, completion: completion)
            }
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func willEnterForeground(_ notification: Notification) {
        // Restarts the server if it was stopped while the app was in the
        // background.
        queue.sync(flags: .barrier) {
            guard
                case let .started(port, _) = state,
                isPortFree(port)
            else {
                return
            }

            do {
                try startWithPort(server.port)
            } catch {
                log(.error, error)
            }
        }
    }

    private func handle(request: ReadiumGCDWebServerRequest, completion: @escaping ReadiumGCDWebServerCompletionBlock) {
        responseResource(for: request) { httpServerRequest, resource, failureHandler in
            let response: ReadiumGCDWebServerResponse
            switch resource.length {
            case let .success(length):
                response = ResourceResponse(
                    resource: resource,
                    length: length,
                    range: request.hasByteRange() ? request.byteRange : nil
                )
            case let .failure(error):
                self.log(.error, error)
                failureHandler?(httpServerRequest, error)
                response = ReadiumGCDWebServerErrorResponse(
                    statusCode: error.httpStatusCode,
                    error: error
                )
            }

            completion(response) // goes back to ReadiumGCDWebServerConnection.m
        }
    }

    private func responseResource(
        for request: ReadiumGCDWebServerRequest,
        completion: @escaping (HTTPServerRequest, Resource, HTTPRequestHandler.OnFailure?) -> Void
    ) {
        let completion = { request, resource, failureHandler in
            // Escape the queue to avoid deadlocks if something is using the
            // server in the handler.
            DispatchQueue.global().async {
                completion(request, resource, failureHandler)
            }
        }

        queue.async { [self] in
            guard let url = request.url.httpURL else {
                fatalError("Expected an HTTP URL")
            }

            func transform(resource: Resource, at endpoint: HTTPURL) -> Resource {
                guard let transformers = transformers[endpoint], !transformers.isEmpty else {
                    return resource
                }
                var resource = resource
                for transformer in transformers {
                    resource = transformer(resource)
                }
                return resource
            }

            let pathWithoutAnchor = url.removingQuery().removingFragment()

            for (endpoint, handler) in handlers {
                if endpoint == pathWithoutAnchor {
                    let request = HTTPServerRequest(url: url, href: nil)
                    let resource = handler.onRequest(request)
                    completion(
                        request,
                        transform(resource: resource, at: endpoint),
                        handler.onFailure
                    )
                    return

                } else if let href = endpoint.relativize(url) {
                    let request = HTTPServerRequest(
                        url: url,
                        href: href
                    )
                    let resource = handler.onRequest(request)
                    completion(
                        request,
                        transform(resource: resource, at: endpoint),
                        handler.onFailure
                    )
                    return
                }
            }

            log(.warning, "Resource not found for request \(request)")
            completion(
                HTTPServerRequest(url: url, href: nil),
                FailureResource(
                    link: Link(href: request.url.absoluteString),
                    error: .notFound(nil)
                ),
                nil
            )
        }
    }

    // MARK: HTTPServer

    public func serve(
        at endpoint: HTTPServerEndpoint,
        handler: HTTPRequestHandler
    ) throws -> HTTPURL {
        try queue.sync(flags: .barrier) {
            if case .stopped = state {
                try start()
            }

            let url = try url(for: endpoint)
            handlers[url] = handler
            return url
        }
    }

    public func transformResources(at endpoint: HTTPServerEndpoint, with transformer: @escaping ResourceTransformer) throws {
        try queue.sync(flags: .barrier) {
            let url = try url(for: endpoint)
            var trs = transformers[url] ?? []
            trs.append(transformer)
            transformers[url] = trs
        }
    }

    public func remove(at endpoint: HTTPServerEndpoint) throws {
        try queue.sync(flags: .barrier) {
            let url = try url(for: endpoint)
            handlers.removeValue(forKey: url)
            transformers.removeValue(forKey: url)
        }
    }

    private func url(for endpoint: HTTPServerEndpoint) throws -> HTTPURL {
        guard case let .started(port: _, baseURL: baseURL) = state else {
            throw GCDHTTPServerError.serverNotStarted
        }
        guard
            let endpointPath = RelativeURL(string: endpoint.addingSuffix("/")),
            let endpointURL = baseURL.resolve(endpointPath)
        else {
            throw GCDHTTPServerError.invalidEndpoint(endpoint)
        }
        return endpointURL
    }

    // MARK: Server lifecycle

    private func stop() {
        dispatchPrecondition(condition: .onQueueAsBarrier(queue))
        server.stop()
        state = .stopped
    }

    private func start() throws {
        func makeRandomPort() -> UInt {
            // https://en.wikipedia.org/wiki/Ephemeral_port#Range
            let lowerBound = 49152
            let upperBound = 65535
            return UInt(lowerBound + Int(arc4random_uniform(UInt32(upperBound - lowerBound))))
        }

        var attemptsLeft = 50
        while attemptsLeft > 0 {
            attemptsLeft -= 1

            do {
                try startWithPort(makeRandomPort())
                return
            } catch {
                log(.error, error)
                if attemptsLeft == 0 {
                    throw error
                }
            }
        }
    }

    private func startWithPort(_ port: UInt) throws {
        dispatchPrecondition(condition: .onQueueAsBarrier(queue))

        stop()

        do {
            try server.start(options: [
                ReadiumGCDWebServerOption_Port: port,
                ReadiumGCDWebServerOption_BindToLocalhost: true,
                // We disable automatically suspending the server in the
                // background, to be able to play audiobooks even with the
                // screen locked.
                ReadiumGCDWebServerOption_AutomaticallySuspendInBackground: false,
            ])
        } catch {
            throw GCDHTTPServerError.failedToStartServer(cause: error)
        }

        guard let baseURL = server.serverURL?.httpURL else {
            stop()
            throw GCDHTTPServerError.nullServerURL
        }

        state = .started(port: server.port, baseURL: baseURL)
    }

    /// Checks if the given port is already taken (presumabily by the server).
    /// Inspired by https://stackoverflow.com/questions/33086356/swift-2-check-if-port-is-busy
    private func isPortFree(_ port: UInt) -> Bool {
        let port = in_port_t(port)

        func getErrnoMessage() -> String {
            String(cString: UnsafePointer(strerror(errno)))
        }

        let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        if socketDescriptor == -1 {
            // Just in case, returns true to attempt restarting the server.
            return true
        }
        defer {
            Darwin.shutdown(socketDescriptor, SHUT_RDWR)
            close(socketDescriptor)
        }

        let addrSize = MemoryLayout<sockaddr_in>.size
        var addr = sockaddr_in()
        addr.sin_len = __uint8_t(addrSize)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = Int(OSHostByteOrder()) == OSLittleEndian ? _OSSwapInt16(port) : port
        addr.sin_addr = in_addr(s_addr: inet_addr("0.0.0.0"))
        addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        var bindAddr = sockaddr()
        memcpy(&bindAddr, &addr, Int(addrSize))

        if Darwin.bind(socketDescriptor, &bindAddr, socklen_t(addrSize)) == -1 {
            // "Address already in use", the server is already started
            if errno == EADDRINUSE {
                return false
            }
        }

        // It might not actually be free, but we'll try to restart the server.
        return true
    }
}
