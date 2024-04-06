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
    typealias FailureHandler = (_ request: HTTPServerRequest, _ error: ResourceError) -> Void

    /// Serves resources at the given `endpoint`.
    ///
    /// Subsequent calls with the same `endpoint` overwrite each other.
    ///
    /// - Returns the base URL for this endpoint.
    @discardableResult
    func serve(
        at endpoint: HTTPServerEndpoint,
        handler: @escaping (HTTPServerRequest) -> Resource
    ) throws -> HTTPURL

    /// Serves resources at the given `endpoint`.
    ///
    /// Subsequent calls with the same `endpoint` overwrite each other.
    ///
    /// If the resource cannot be served, the `failureHandler` is called.
    ///
    /// - Returns the base URL for this endpoint.
    @discardableResult
    func serve(
        at endpoint: HTTPServerEndpoint,
        handler: @escaping (HTTPServerRequest) -> Resource,
        failureHandler: FailureHandler?
    ) throws -> HTTPURL

    /// Registers a `Resource` transformer that will be run on all responses
    /// matching the given `endpoint`.
    func transformResources(at endpoint: HTTPServerEndpoint, with transformer: @escaping ResourceTransformer) throws

    /// Removes a handler serving resources at `endpoint`, as well as the
    /// resource transformers.
    func remove(at endpoint: HTTPServerEndpoint) throws
}

public extension HTTPServer {
    @discardableResult
    func serve(
        at endpoint: HTTPServerEndpoint,
        handler: @escaping (HTTPServerRequest) -> Resource,
        failureHandler: FailureHandler?
    ) throws -> HTTPURL {
        try serve(at: endpoint, handler: handler)
    }

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
        failureHandler: FailureHandler? = nil
    ) throws -> HTTPURL {
        func handler(request: HTTPServerRequest) -> Resource {
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
            handler: handler(request:),
            failureHandler: failureHandler
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
        failureHandler: FailureHandler? = nil
    ) throws -> HTTPURL {
        func handler(request: HTTPServerRequest) -> Resource {
            guard let href = request.href else {
                failureHandler?(request, .notFound(nil))

                return FailureResource(
                    link: Link(href: request.url.string),
                    error: .notFound(nil)
                )
            }

            return publication.get(href.string)
        }

        return try serve(
            at: endpoint,
            handler: handler(request:),
            failureHandler: failureHandler
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
