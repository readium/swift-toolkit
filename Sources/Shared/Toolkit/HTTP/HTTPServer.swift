//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Serves resources through HTTP.
///
/// This is required by some Navigators to access a local publication's
/// resources.
public protocol HTTPServer {
    /// Serves resources at the given `endpoint`.
    ///
    /// Subsequent calls with the same `endpoint` overwrite each other.
    ///
    /// - Returns the base URL for this endpoint.
    @discardableResult
    func serve(
        at endpoint: HTTPServerEndpoint,
        handler: HTTPRequestHandler
    ) throws -> HTTPURL

    /// Registers a `Resource` transformer that will be run on all responses
    /// matching the given `endpoint`.
    func transformResources(at endpoint: HTTPServerEndpoint, with transformer: @escaping ResourceTransformer) throws

    /// Removes a handler serving resources at `endpoint`, as well as the
    /// resource transformers.
    func remove(at endpoint: HTTPServerEndpoint) throws
}

public extension HTTPServer {
    /// Serves the local file `url` at the given `endpoint`.
    ///
    /// If the provided `url` is a directory, then all the files in the
    /// directory are served. Subsequent calls with the same served `endpoint`
    /// overwrite each other.
    ///
    /// If the file cannot be served, the `failureHandler` is called.
    ///
    /// - Returns the URL to access the file(s) on the server.
    @discardableResult
    func serve(
        at endpoint: HTTPServerEndpoint,
        contentsOf url: FileURL,
        onFailure: HTTPRequestHandler.OnFailure? = nil
    ) throws -> HTTPURL {
        func onRequest(request: HTTPServerRequest) -> HTTPServerResponse {
            let file = request.href.flatMap { url.resolve($0) }
                ?? url

            return HTTPServerResponse(
                resource: FileResource(file: file),
                mediaType: nil
            )
        }

        return try serve(
            at: endpoint,
            handler: HTTPRequestHandler(
                onRequest: onRequest,
                onFailure: onFailure
            )
        )
    }

    /// Serves a `publication`'s resources at the given `endpoint`.
    ///
    /// If the resource cannot be served, the `failureHandler` is called.
    ///
    /// - Returns the base URL to access the publication's resources on the
    /// server.
    @discardableResult
    func serve(
        at endpoint: HTTPServerEndpoint,
        publication: Publication,
        onFailure: HTTPRequestHandler.OnFailure? = nil
    ) throws -> HTTPURL {
        func onRequest(request: HTTPServerRequest) -> HTTPServerResponse {
            lazy var notFound = HTTPError.errorResponse(HTTPResponse(
                request: HTTPRequest(url: request.url),
                url: request.url,
                status: .notFound,
                headers: [:],
                mediaType: nil,
                body: nil
            ))

            guard
                let href = request.href,
                let link = publication.linkWithHREF(href),
                let resource = publication.get(href)
            else {
                onFailure?(request, .access(.http(notFound)))

                return HTTPServerResponse(error: notFound)
            }

            return HTTPServerResponse(
                resource: resource,
                mediaType: link.mediaType
            )
        }

        return try serve(
            at: endpoint,
            handler: HTTPRequestHandler(
                onRequest: onRequest,
                onFailure: onFailure
            )
        )
    }
}

/// A endpoint is a base HREF on a server where resources are served.
public typealias HTTPServerEndpoint = String

/// Request made to an `HTTPServer`.
public struct HTTPServerRequest {
    /// Absolute URL on the server.
    public let url: HTTPURL

    /// HREF for the resource, relative to the server endpoint.
    public let href: RelativeURL?

    public init(url: HTTPURL, href: RelativeURL?) {
        self.url = url
        self.href = href
    }
}

/// Response sent from the `HTTPServer` when receiving a request.
public struct HTTPServerResponse {
    public var resource: Resource
    public var mediaType: MediaType?

    public init(resource: Resource, mediaType: MediaType?) {
        self.resource = resource
        self.mediaType = mediaType
    }

    public init(error: HTTPError) {
        self.init(
            resource: FailureResource(error: .access(.http(error))),
            mediaType: nil
        )
    }
}

/// Callbacks handling a request.
///
/// If the resource cannot be served, the `onFailure` callback is called.
public struct HTTPRequestHandler {
    public typealias OnRequest = (_ request: HTTPServerRequest) -> HTTPServerResponse
    public typealias OnFailure = (_ request: HTTPServerRequest, _ error: ReadError) -> Void

    public let onRequest: OnRequest
    public let onFailure: OnFailure?

    public init(onRequest: @escaping OnRequest, onFailure: OnFailure? = nil) {
        self.onRequest = onRequest
        self.onFailure = onFailure
    }
}
