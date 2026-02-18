//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumShared
import WebKit

/// A generic `WKURLSchemeHandler` that serves files, directories, and
/// arbitrary resources at named routes using a custom URL scheme (e.g.
/// `readium://`).
@MainActor final class WebViewServer: NSObject, WKURLSchemeHandler, Loggable {
    /// The custom scheme used to serve the content.
    let scheme: String

    /// Format sniffer used to infer the media type of served resources.
    let formatSniffer: FormatSniffer

    init(scheme: String, formatSniffer: FormatSniffer) {
        self.scheme = scheme
        self.formatSniffer = formatSniffer
        super.init()
    }

    // MARK: - Route registration

    private enum RouteHandler {
        case file(FileURL)
        case directory(FileURL)
        case resources(@MainActor (RelativeURL) async -> (Resource, MediaType)?)
    }

    /// Registered routes, sorted by reverse alphabetical order to ensure
    /// longest-prefix matching of routes sharing a common prefix.
    private var routes: [(path: String, baseURL: AbsoluteURL, handler: RouteHandler)] = []

    /// Serves a single local file at the given route.
    ///
    /// - Returns: The absolute URL (e.g. `readium://assets/fonts/abc/Font.otf`)
    ///   to the served file.
    @discardableResult
    func serve(file: FileURL, at route: String) -> AbsoluteURL {
        let route = normalizedRoute(route)
        let baseURL = AnyURL(string: "\(scheme)://\(route)")!.absoluteURL!
        insertRoute((path: route, baseURL: baseURL, handler: .file(file)))
        return baseURL
    }

    /// Serves a local directory at the given route.
    ///
    /// All files under the directory are accessible.
    ///
    /// - Returns: The absolute base URL (e.g. `readium://assets/`) to the
    ///   served directory.
    @discardableResult
    func serve(directory: FileURL, at route: String) -> AbsoluteURL {
        let route = normalizedRoute(route, isDirectory: true)
        let baseURL = AnyURL(string: "\(scheme)://\(route)")!.absoluteURL!
        insertRoute((path: route, baseURL: baseURL, handler: .directory(directory)))
        return baseURL
    }

    /// Serves resources at the given route using a handler callback.
    ///
    /// The handler receives a relative URL and returns a `Resource`, or
    /// `nil` for 404. Returned resources are automatically wrapped in a
    /// `BufferingResource` cache.
    ///
    /// Returns the base URL (e.g. `readium://{uuid}/`).
    @discardableResult
    func serve(at route: String, handler: @escaping @MainActor (RelativeURL) async -> (Resource, MediaType)?) -> AbsoluteURL {
        let route = normalizedRoute(route, isDirectory: true)
        let baseURL = AnyURL(string: "\(scheme)://\(route)")!.absoluteURL!
        insertRoute((path: route, baseURL: baseURL, handler: .resources(handler)))
        return baseURL
    }

    /// Removes the handler at the given route.
    func remove(at route: String) {
        let route = normalizedRoute(route)
        routes.removeAll { $0.path.hasPrefix(route) }
    }

    private func normalizedRoute(_ route: String, isDirectory: Bool = false) -> String {
        var r = route.removingPrefix("/")
        if isDirectory {
            r = r.addingSuffix("/")
        }
        return r
    }

    private func insertRoute(_ entry: (path: String, baseURL: AbsoluteURL, handler: RouteHandler)) {
        // Remove any existing route with the same path.
        routes.removeAll { $0.path == entry.path }
        routes.append(entry)
        // Reverse alphabetical order ensures longest-prefix matching:
        // routes sharing a common prefix are grouped with longer ones first.
        routes.sort { $0.path > $1.path }
    }

    // MARK: - Active tasks & caching

    /// Tracks active tasks for cancellation support.
    private var activeTasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    /// Bounded cache of buffered resources keyed by publication-relative URL.
    ///
    /// Reusing the same ``Resource`` across requests lets compressed ZIP
    /// resources benefit from forward-seek optimization instead of
    /// decompressing from offset 0 on every request.
    ///
    /// Oldest entries are evicted when the cache exceeds its capacity.
    private var resourceCache = BoundedResourceCache()

    // MARK: - WKURLSchemeHandler

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask)
        activeTasks[taskID] = Task {
            await serve(urlSchemeTask)
            _ = activeTasks.removeValue(forKey: taskID)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask)
        activeTasks.removeValue(forKey: taskID)?.cancel()
    }

    // MARK: - Serving

    private func serve(_ urlSchemeTask: WKURLSchemeTask) async {
        guard let requestURL = urlSchemeTask.request.url else {
            await fail(urlSchemeTask, with: URLError(.badURL))
            return
        }

        // Find the matching route (longest prefix wins).
        for route in routes {
            switch route.handler {
            case let .file(file):
                guard route.baseURL.isEquivalentTo(requestURL) else {
                    continue
                }
                await serveFile(urlSchemeTask, at: file, requestURL: requestURL)
                return

            case let .directory(directory):
                guard
                    let relativeURL = route.baseURL.relativize(requestURL),
                    let file = directory.resolve(relativeURL)?.fileURL,
                    directory.isParent(of: file)
                else {
                    continue
                }
                await serveFile(urlSchemeTask, at: file, requestURL: requestURL)
                return

            case let .resources(handler):
                guard let relativeURL = route.baseURL.relativize(requestURL) else {
                    continue
                }
                await serveResource(
                    urlSchemeTask,
                    relativeURL: relativeURL,
                    handler: handler,
                    requestURL: requestURL
                )
                return
            }
        }

        await fail(urlSchemeTask, with: URLError(.fileDoesNotExist))
    }

    /// Serves a resource from a handler callback, with caching.
    private func serveResource(
        _ urlSchemeTask: WKURLSchemeTask,
        relativeURL: RelativeURL,
        handler: @MainActor (RelativeURL) async -> (Resource, MediaType)?,
        requestURL: URL
    ) async {
        // Reuse a cached buffered resource to benefit from forward-seek
        // optimization and read-ahead buffering, or create and cache a new
        // one.
        let resource: Resource
        let mediaType: MediaType
        if let (cachedResource, cachedMediaType) = resourceCache[relativeURL] {
            resource = cachedResource
            mediaType = cachedMediaType
        } else {
            guard let (newResource, newMediaType) = await handler(relativeURL) else {
                await fail(urlSchemeTask, with: URLError(.fileDoesNotExist))
                return
            }
            resource = newResource.buffered(size: 256 * 1024)
            mediaType = newMediaType
            resourceCache.set(relativeURL, resource: resource, mediaType: mediaType)
        }

        await serveResource(
            resource,
            with: urlSchemeTask,
            mediaType: mediaType,
            requestURL: requestURL
        )
    }

    /// Reads a local file and sends it as a response.
    private func serveFile(
        _ urlSchemeTask: WKURLSchemeTask,
        at file: FileURL,
        requestURL: URL
    ) async {
        await serveResource(
            FileResource(file: file),
            with: urlSchemeTask,
            mediaType: mediaTypeFromURL(file),
            requestURL: requestURL
        )
    }

    private func serveResource(
        _ resource: Resource,
        with urlSchemeTask: WKURLSchemeTask,
        mediaType: MediaType?,
        requestURL: URL
    ) async {
        // Try to serve a byte range if the client requested one and the
        // resource length is known.
        if
            let totalLength = await (try? resource.estimatedLength().get()).flatMap({ $0 }),
            let range = urlSchemeTask.request.byteRange(in: totalLength)
        {
            let result = await resource.read(range: range)
            switch result {
            case let .success(data):
                await respond(urlSchemeTask, with: data, range: range, totalLength: totalLength, mediaType: mediaType, url: requestURL)
            case let .failure(error):
                log(.error, "Failed to read resource \(requestURL.path) range \(range): \(error)")
                await fail(urlSchemeTask, with: URLError(.resourceUnavailable))
            }
            return
        }

        // Full read fallback.
        let result = await resource.read()
        switch result {
        case let .success(data):
            await respond(urlSchemeTask, with: data, range: nil, totalLength: UInt64(data.count), mediaType: mediaType, url: requestURL)
        case let .failure(error):
            log(.error, "Failed to read resource \(requestURL.path): \(error)")
            await fail(urlSchemeTask, with: URLError(.resourceUnavailable))
        }
    }

    private func mediaTypeFromURL(_ url: URLConvertible) -> MediaType? {
        guard let ext = url.anyURL.pathExtension else {
            return nil
        }
        return formatSniffer.sniffHints(FormatHints(fileExtension: ext))?.mediaType
    }

    // MARK: - Response helpers

    /// Sends data as a response, optionally as a 206 Partial Content when a
    /// byte range was requested.
    ///
    /// - Parameters:
    ///   - range: The byte range being served, or `nil` for a full 200
    ///     response.
    ///   - totalLength: The total size of the resource (used in
    ///     `Content-Range`).
    private func respond(
        _ urlSchemeTask: WKURLSchemeTask,
        with data: Data,
        range: Range<UInt64>?,
        totalLength: UInt64,
        mediaType: MediaType?,
        url: URL
    ) async {
        var headers: [String: String] = [
            "Content-Length": "\(data.count)",
            "Accept-Ranges": "bytes",
        ]

        if let mediaType {
            headers["Content-Type"] = mediaType.string
        }

        let statusCode: Int
        if let range = range {
            statusCode = 206
            headers["Content-Range"] = "bytes \(range.lowerBound)-\(range.upperBound - 1)/\(totalLength)"
        } else {
            statusCode = 200
        }

        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            await fail(urlSchemeTask, with: URLError(.unknown))
            return
        }

        // Guard against task cancellation to avoid calling WKURLSchemeTask
        // methods after WebKit has stopped the task.
        guard !Task.isCancelled else { return }
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    private func fail(_ urlSchemeTask: WKURLSchemeTask, with error: Error) async {
        guard !Task.isCancelled else { return }
        urlSchemeTask.didFailWithError(error)
    }
}

private extension URLRequest {
    /// Parses an HTTP `Range` header value (RFC 7233) into a byte range.
    func byteRange(in totalLength: UInt64) -> Range<UInt64>? {
        Range(httpRange: value(forHTTPHeaderField: "Range") ?? "", in: totalLength)
    }
}

/// A simple bounded FIFO cache for ``Resource`` instances.
///
/// Evicts the oldest entries when the number of cached resources exceeds
/// ``capacity``, preventing unbounded memory growth as the user navigates
/// through chapters.
private struct BoundedResourceCache {
    private let capacity = 8
    private var entries: [RelativeURL: (Resource, MediaType)] = [:]
    private var order: [RelativeURL] = []

    subscript(key: RelativeURL) -> (Resource, MediaType)? {
        entries[key]
    }

    mutating func set(_ key: RelativeURL, resource: Resource, mediaType: MediaType) {
        if entries[key] == nil {
            order.append(key)
        }
        entries[key] = (resource, mediaType)

        while order.count > capacity {
            let evicted = order.removeFirst()
            entries.removeValue(forKey: evicted)
        }
    }
}
