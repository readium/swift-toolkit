//
//  Copyright 2024 Readium Foundation. All rights reserved.
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
        func onRequest(request: HTTPServerRequest) -> Resource {
            let file = request.href.flatMap { url.resolve($0) }
                ?? url

            return FileResource(
                link: Link(
                    href: request.url.string,
                    type: MediaType.of(file)?.string
                ),
                file: file
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
        func onRequest(request: HTTPServerRequest) -> Resource {
            guard let href = request.href else {
                onFailure?(request, .notFound(nil))

                return FailureResource(
                    link: Link(href: request.url.string),
                    error: .notFound(nil)
                )
            }

            return publication.get(href.string)
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

/// Callbacks handling a request.
///
/// If the resource cannot be served, the `onFailure` callback is called.
public struct HTTPRequestHandler {
    public typealias OnRequest = (_ request: HTTPServerRequest) -> Resource
    public typealias OnFailure = (_ request: HTTPServerRequest, _ error: ResourceError) -> Void

    public let onRequest: OnRequest
    public let onFailure: OnFailure?

    public init(onRequest: @escaping OnRequest, onFailure: OnFailure? = nil) {
        self.onRequest = onRequest
        self.onFailure = onFailure
    }
}
