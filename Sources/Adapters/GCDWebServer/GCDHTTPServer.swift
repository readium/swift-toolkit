//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumGCDWebServer
import ReadiumInternal
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
    /// The actual underlying HTTP server instance.
    private let server = ReadiumGCDWebServer()

    /// Mapping between endpoints and their handlers.
    private var handlers: [HTTPURL: HTTPRequestHandler] = [:]

    /// Mapping between endpoints and resource transformers.
    private var transformers: [HTTPURL: [ResourceTransformer]] = [:]

    private let assetRetriever: AssetRetriever

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
    public init(
        assetRetriever: AssetRetriever,
        logLevel: Int = 3
    ) {
        self.assetRetriever = assetRetriever

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
        responseResource(for: request) { httpServerRequest, httpServerResponse, failureHandler in
            Task {
                let response: ReadiumGCDWebServerResponse
                let resource = httpServerResponse.resource

                func fail(_ error: ReadError) -> ReadiumGCDWebServerResponse {
                    self.log(.error, error)
                    failureHandler?(httpServerRequest, error)
                    return ReadiumGCDWebServerErrorResponse(
                        statusCode: 500,
                        error: error
                    )
                }

                switch await resource.length() {
                case let .success(length):
                    response = await ResourceResponse(
                        resource: httpServerResponse.resource,
                        length: length,
                        range: request.hasByteRange() ? request.byteRange : nil,
                        mediaType: httpServerResponse.mediaType(using: self.assetRetriever)
                    )
                case let .failure(error):
                    response = fail(error)
                }

                completion(response) // goes back to ReadiumGCDWebServerConnection.m
            }
        }
    }

    private func responseResource(
        for request: ReadiumGCDWebServerRequest,
        completion: @escaping (HTTPServerRequest, HTTPServerResponse, HTTPRequestHandler.OnFailure?) -> Void
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

            func transform(resource: Resource, request: HTTPServerRequest, at endpoint: HTTPURL) -> Resource {
                guard let transformers = transformers[endpoint], !transformers.isEmpty else {
                    return resource
                }
                let href = request.href?.anyURL ?? request.url.anyURL
                var resource = resource
                for transformer in transformers {
                    resource = transformer(href, resource)
                }
                return resource
            }

            let pathWithoutAnchor = url.removingQuery().removingFragment()

            for (endpoint, handler) in handlers {
                let request: HTTPServerRequest
                if endpoint.isEquivalentTo(pathWithoutAnchor) {
                    request = HTTPServerRequest(url: url, href: nil)
                } else if let href = endpoint.relativize(url) {
                    request = HTTPServerRequest(url: url, href: href)
                } else {
                    continue
                }

                var response = handler.onRequest(request)
                response.resource = transform(resource: response.resource, request: request, at: endpoint)
                completion(request, response, handler.onFailure)
                return
            }

            log(.warning, "Resource not found for request \(request)")
            completion(
                HTTPServerRequest(url: url, href: nil),
                HTTPServerResponse(error: .errorResponse(HTTPResponse(
                    request: HTTPRequest(url: url),
                    url: url,
                    status: .notFound,
                    headers: [:],
                    mediaType: nil,
                    body: nil
                ))),
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

private extension Resource {
    func length() async -> ReadResult<UInt64> {
        await estimatedLength()
            .asyncFlatMap { length in
                if let length = length {
                    return .success(length)
                } else {
                    return await read().map { UInt64($0.count) }
                }
            }
    }
}

private extension HTTPServerResponse {
    func mediaType(using assetRetriever: AssetRetriever) async -> MediaType {
        if let mediaType = mediaType {
            return mediaType
        }

        if let properties = try? await resource.properties().get() {
            if let mediaType = properties.mediaType {
                return mediaType
            }
            if
                let filename = properties.filename,
                let uti = UTI.findFrom(mediaTypes: [], fileExtensions: [URL(fileURLWithPath: filename).pathExtension]),
                let type = uti.preferredTag(withClass: .mediaType),
                let mediaType = MediaType(type)
            {
                return mediaType
            }
        }

        if let mediaType = try? await assetRetriever.sniffFormat(of: resource).get().mediaType {
            return mediaType
        }

        return .binary
    }
}
