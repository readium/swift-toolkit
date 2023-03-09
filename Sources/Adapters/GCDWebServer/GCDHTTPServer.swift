//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared
import GCDWebServer
import UIKit

public enum GCDHTTPServerError: Error {
    case failedToStartServer(cause: Error)
    case serverNotStarted
    case nullServerURL
}

/// Implementation of `HTTPServer` using GCDWebServer under the hood.
public class GCDHTTPServer: HTTPServer, Loggable {

    /// Shared instance of the HTTP server.
    public static let shared = GCDHTTPServer()

    /// The actual underlying HTTP server instance.
    private let server = GCDWebServer()
    
    /// Mapping between endpoints and their handlers.
    private var handlers: [HTTPServerEndpoint: (HTTPServerRequest) -> Resource] = [:]

    private enum State {
        case stopped
        case started(port: UInt, baseURL: URL)
    }

    private var state: State = .stopped

    /// Dispatch queue to protect accesses to the handlers and state.
    private let queue = DispatchQueue(
        label: "org.readium.swift-toolkit.ReadiumAdapterGCDWebServer",
        attributes: .concurrent
    )
    
    /// Creates a new instance of the HTTP server.
    ///
    /// - Parameter logLevel: See `GCDWebServer.setLogLevel`.
    init(logLevel: Int = 3) {
        GCDWebServer.setLogLevel(Int32(logLevel))
        
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        server.addDefaultHandler(
            forMethod: "GET",
            request: GCDWebServerRequest.self,
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
                case .started(let port, _) = state,
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

    private func handle(request: GCDWebServerRequest, completion: @escaping GCDWebServerCompletionBlock) {
        queue.async { [self] in
            var path = request.path.removingPrefix("/")
            path = path.removingPercentEncoding ?? path
            // Remove anchors and query params
            path = path.components(separatedBy: .init(charactersIn: "#?")).first ?? path

            let resource: Resource = {
                for (endpoint, handler) in handlers {
                    if endpoint == path {
                        return handler(HTTPServerRequest(url: request.url, href: nil))
                    } else if path.hasPrefix(endpoint.addingSuffix("/")) {
                        return handler(HTTPServerRequest(
                            url: request.url,
                            href: path.removingPrefix(endpoint.removingSuffix("/"))
                        ))
                    }
                }

                return FailureResource(link: Link(href: request.url.absoluteString), error: .notFound(nil))
            }()

            let response: GCDWebServerResponse
            switch resource.length {
            case .success(let length):
                response = ResourceResponse(
                    resource: resource,
                    length: length,
                    range: request.hasByteRange() ? request.byteRange : nil
                )
            case .failure(let error):
                log(.error, error)
                response = GCDWebServerErrorResponse(statusCode: error.httpStatusCode)
            }

            completion(response)
        }
    }

    // MARK: HTTPServer
    
    public func serve(at endpoint: HTTPServerEndpoint, handler: @escaping (HTTPServerRequest) -> Resource) throws -> URL {
        try queue.sync(flags: .barrier) {
            if case .stopped = state {
                try start()
            }
            guard case let .started(port: _, baseURL: baseURL) = state else {
                throw GCDHTTPServerError.serverNotStarted
            }

            handlers[endpoint] = handler

            return baseURL.appendingPathComponent(endpoint)
        }
    }

    public func remove(at endpoint: HTTPServerEndpoint) {
        queue.sync(flags: .barrier) {
            handlers.removeValue(forKey: endpoint)

            if handlers.isEmpty {
                stop()
            }
        }
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
                GCDWebServerOption_Port: port,
                GCDWebServerOption_BindToLocalhost: true,
                // We disable automatically suspending the server in the
                // background, to be able to play audiobooks even with the
                // screen locked.
                GCDWebServerOption_AutomaticallySuspendInBackground: false
            ])
        } catch {
            throw GCDHTTPServerError.failedToStartServer(cause: error)
        }

        guard let baseURL = server.serverURL else {
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
            return String(cString: UnsafePointer(strerror(errno)))
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
