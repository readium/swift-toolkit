//
//  Copyright 2023 Readium Foundation. All rights reserved.
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
    func serve(at endpoint: HTTPServerEndpoint, handler: @escaping (HTTPServerRequest) -> Resource) throws -> URL

    /// Registers a `Resource` transformer that will be run on all responses
    /// matching the given `endpoint`.
    func transformResources(at endpoint: HTTPServerEndpoint, with transformer: @escaping ResourceTransformer)

    /// Removes a handler serving resources at `endpoint`, as well as the
    /// resource transformers.
    func remove(at endpoint: HTTPServerEndpoint)
}

public extension HTTPServer {
    /// Serves the local file `url` at the given `endpoint`.
    ///
    /// If the provided `url` is a directory, then all the files in the
    /// directory are served. Subsequent calls with the same served `endpoint`
    /// overwrite each other.
    ///
    /// - Returns the URL to access the file(s) on the server.
    @discardableResult
    func serve(at endpoint: HTTPServerEndpoint, contentsOf url: URL) throws -> URL {
        try serve(at: endpoint) { request in
            let file = url.appendingPathComponent(request.href ?? "")

            return FileResource(
                link: Link(
                    href: request.url.absoluteString,
                    type: MediaType.of(file)?.string
                ),
                file: file
            )
        }
    }

    /// Serves a `publication`'s resources at the given `endpoint`.
    ///
    /// - Returns the base URL to access the publication's resources on the
    /// server.
    @discardableResult
    func serve(
        at endpoint: HTTPServerEndpoint,
        publication: Publication
    ) throws -> URL {
        try serve(at: endpoint) { request in
            guard let href = request.href else {
                return FailureResource(
                    link: Link(href: request.url.absoluteString),
                    error: .notFound(nil)
                )
            }

            return publication.get(href)
        }
    }
}

/// A endpoint is a base HREF on a server where resources are served.
public typealias HTTPServerEndpoint = String

/// Request made to an `HTTPServer`.
public struct HTTPServerRequest {
    /// Absolute URL on the server.
    public let url: URL

    /// HREF for the resource, relative to the server endpoint.
    public let href: String?

    public init(url: URL, href: String?) {
        self.url = url
        self.href = href
    }
}
