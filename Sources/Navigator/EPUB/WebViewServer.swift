//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UniformTypeIdentifiers
import WebKit

/// A generic `WKURLSchemeHandler` that serves files, directories, and
/// arbitrary resources at named routes using a custom URL scheme (e.g.
/// `readium://`).
@MainActor final class WebViewServer: NSObject, WKURLSchemeHandler, Loggable {
    /// The custom scheme used to serve the content.
    let scheme: String

    init(scheme: String) {
        self.scheme = scheme
        super.init()
    }

    // MARK: - Route registration

    private enum RouteHandler {
        case file(FileURL)
        case directory(FileURL)
        case resources(@MainActor (RelativeURL) -> Resource?)
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
    func serve(at route: String, handler: @escaping @MainActor (RelativeURL) -> Resource?) -> AbsoluteURL {
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
    /// Only accessed from the main thread (WebKit calls start/stop on main).
    private var activeTasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    /// Bounded cache of buffered resources keyed by publication-relative URL.
    ///
    /// Reusing the same ``BufferingResource`` (and its underlying source)
    /// across requests lets compressed ZIP resources benefit from forward-seek
    /// optimization instead of decompressing from offset 0 on every request.
    ///
    /// Oldest entries are evicted when the cache exceeds its capacity.
    private var resourceCache = BoundedResourceCache()

    // MARK: - WKURLSchemeHandler

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask)
        activeTasks[taskID] = Task {
            await serve(urlSchemeTask)
            await MainActor.run { [weak self] in
                _ = self?.activeTasks.removeValue(forKey: taskID)
            }
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

        let anyURL = AnyURL(url: requestURL)

        // Find the matching route (longest prefix wins).
        for route in routes {
            switch route.handler {
            case let .file(file):
                // File routes match on exact URL equality since
                // relativize returns nil for identical URLs.
                guard anyURL == route.baseURL.anyURL else {
                    continue
                }
                await serveFile(urlSchemeTask, at: file, requestURL: requestURL)
                return

            case let .directory(directory):
                guard
                    let relativeURL = route.baseURL.relativize(anyURL),
                    let file = directory.resolve(relativeURL)?.fileURL
                else {
                    continue
                }
                await serveFile(urlSchemeTask, at: file, requestURL: requestURL)
                return

            case let .resources(handler):
                guard let relativeURL = route.baseURL.relativize(anyURL) else {
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
        handler: @MainActor (RelativeURL) -> Resource?,
        requestURL: URL
    ) async {
        // Reuse a cached buffered resource to benefit from forward-seek
        // optimization and read-ahead buffering, or create and cache a new
        // one.
        let resource: BufferingResource
        if let cached = resourceCache[relativeURL] {
            resource = cached
        } else {
            guard let res = await handler(relativeURL) else {
                await fail(urlSchemeTask, with: URLError(.fileDoesNotExist))
                return
            }
            let buffered = BufferingResource(source: res)
            resourceCache.set(relativeURL, buffered)
            resource = buffered
        }

        let mediaType = relativeURL.pathExtension
            .flatMap { UTType(filenameExtension: $0.rawValue)?.preferredMIMEType }
            ?? "application/octet-stream"

        // Try to serve a byte range if the client requested one and the
        // resource length is known.
        let estimatedLength = await (try? resource.estimatedLength().get()).flatMap { $0 }

        if let totalLength = estimatedLength,
           let range = parseByteRange(from: urlSchemeTask.request, totalLength: totalLength)
        {
            let result = await resource.read(range: range)
            switch result {
            case let .success(data):
                await respond(urlSchemeTask, with: data, range: range, totalLength: totalLength, mimeType: mediaType, url: requestURL)
            case let .failure(error):
                log(.error, "Failed to read resource \(relativeURL) range \(range): \(error)")
                await fail(urlSchemeTask, with: URLError(.resourceUnavailable))
            }
            return
        }

        // Full read fallback.
        let result = await resource.read()
        switch result {
        case let .success(data):
            await respond(urlSchemeTask, with: data, range: nil, totalLength: UInt64(data.count), mimeType: mediaType, url: requestURL)
        case let .failure(error):
            log(.error, "Failed to read resource \(relativeURL): \(error)")
            await fail(urlSchemeTask, with: URLError(.resourceUnavailable))
        }
    }

    /// Reads a local file and sends it as a response.
    private func serveFile(
        _ urlSchemeTask: WKURLSchemeTask,
        at file: FileURL,
        requestURL: URL
    ) async {
        let resource = FileResource(file: file)
        let mimeType = file.pathExtension
            .flatMap { UTType(filenameExtension: $0.rawValue)?.preferredMIMEType }
            ?? "application/octet-stream"

        // Try to serve a byte range if the client requested one and the
        // file length is known.
        if let totalLength = await (try? resource.estimatedLength().get()).flatMap({ $0 }),
           let range = parseByteRange(from: urlSchemeTask.request, totalLength: totalLength)
        {
            let result = await resource.read(range: range)
            switch result {
            case let .success(data):
                await respond(urlSchemeTask, with: data, range: range, totalLength: totalLength, mimeType: mimeType, url: requestURL)
            case let .failure(error):
                log(.error, "Failed to read file \(file) range \(range): \(error)")
                await fail(urlSchemeTask, with: URLError(.fileDoesNotExist))
            }
            return
        }

        // Full read fallback.
        let result = await resource.read()
        switch result {
        case let .success(data):
            await respond(urlSchemeTask, with: data, range: nil, totalLength: UInt64(data.count), mimeType: mimeType, url: requestURL)
        case let .failure(error):
            log(.error, "Failed to read file \(file): \(error)")
            await fail(urlSchemeTask, with: URLError(.fileDoesNotExist))
        }
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
        mimeType: String,
        url: URL
    ) async {
        var headers: [String: String] = [
            "Content-Length": "\(data.count)",
            "Content-Type": mimeType,
            "Accept-Ranges": "bytes",
        ]

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

        // Deliver the response atomically on the main actor, guarding
        // against task cancellation to avoid calling WKURLSchemeTask
        // methods after WebKit has stopped the task.
        await MainActor.run {
            guard !Task.isCancelled else { return }
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        }
    }

    private func fail(_ urlSchemeTask: WKURLSchemeTask, with error: Error) async {
        await MainActor.run {
            guard !Task.isCancelled else { return }
            urlSchemeTask.didFailWithError(error)
        }
    }

    /// Parses a `Range: bytes=X-Y` header from the request.
    ///
    /// Supports RFC 7233 byte range forms:
    /// - `bytes=0-1023` → 0..<1024
    /// - `bytes=1024-` → 1024..<totalLength
    /// - `bytes=-512` → (totalLength-512)..<totalLength
    ///
    /// Returns `nil` if the header is absent or malformed.
    private func parseByteRange(from request: URLRequest, totalLength: UInt64) -> Range<UInt64>? {
        guard
            let header = request.value(forHTTPHeaderField: "Range"),
            header.hasPrefix("bytes=")
        else {
            return nil
        }

        let spec = header.dropFirst("bytes=".count)

        // Suffix range: bytes=-N
        if spec.hasPrefix("-") {
            guard let suffix = UInt64(spec.dropFirst()), suffix > 0 else { return nil }
            let start = totalLength > suffix ? totalLength - suffix : 0
            return start ..< totalLength
        }

        let parts = spec.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let start = UInt64(parts[0]) else { return nil }

        if parts[1].isEmpty {
            // Open-ended range: bytes=N-
            guard start < totalLength else { return nil }
            return start ..< totalLength
        }

        // Closed range: bytes=N-M
        guard let end = UInt64(parts[1]), end >= start else { return nil }
        let clampedEnd = min(end + 1, totalLength)
        guard start < clampedEnd else { return nil }
        return start ..< clampedEnd
    }
}

/// A simple bounded FIFO cache for ``BufferingResource`` instances.
///
/// Evicts the oldest entries when the number of cached resources exceeds
/// ``capacity``, preventing unbounded memory growth as the user navigates
/// through chapters.
private struct BoundedResourceCache {
    private let capacity = 16
    private var entries: [RelativeURL: BufferingResource] = [:]
    private var order: [RelativeURL] = []

    subscript(key: RelativeURL) -> BufferingResource? {
        entries[key]
    }

    mutating func set(_ key: RelativeURL, _ value: BufferingResource) {
        if entries[key] == nil {
            order.append(key)
        }
        entries[key] = value

        while order.count > capacity {
            let evicted = order.removeFirst()
            entries.removeValue(forKey: evicted)
        }
    }
}

/// A `Resource` decorator that buffers reads from the source by reading
/// ahead in larger chunks.
///
/// This efficiently serves the many small sequential range requests that
/// WebKit sends via `WKURLSchemeHandler` for media resources. Instead of
/// hitting the underlying resource (e.g. a compressed ZIP entry) for each
/// tiny request, a single larger read fills the buffer and subsequent
/// requests are served from memory.
///
/// The underlying source `Resource` (e.g. `MinizipResource`) also benefits
/// from being reused: its internal decompression stream stays positioned at
/// the last read offset, so forward reads only decompress the delta instead
/// of starting over from the beginning of the entry.
private actor BufferingResource: Resource, Loggable {
    /// `nonisolated(unsafe)` is safe here because `source` is a `let`
    /// constant set once in `init` and never mutated.
    private nonisolated(unsafe) let source: Resource
    private let readAheadSize: Int

    /// Buffered data and the source offset it starts at.
    private var buffer: Data = .init()
    private var bufferStart: UInt64 = 0

    init(source: Resource, readAheadSize: Int = 256 * 1024) {
        self.source = source
        self.readAheadSize = readAheadSize
    }

    nonisolated var sourceURL: AbsoluteURL? {
        source.sourceURL
    }

    func estimatedLength() async -> ReadResult<UInt64?> {
        await source.estimatedLength()
    }

    func properties() async -> ReadResult<ResourceProperties> {
        await source.properties()
    }

    nonisolated func close() {
        source.close()
    }

    func stream(
        range: Range<UInt64>?,
        consume: @escaping (Data) -> Void
    ) async -> ReadResult<Void> {
        // Full reads pass through to the source.
        guard let range = range, !range.isEmpty else {
            return await source.stream(range: range, consume: consume)
        }

        // Serve from the buffer if the request is fully covered.
        let bufferEnd = bufferStart + UInt64(buffer.count)
        if range.lowerBound >= bufferStart, range.upperBound <= bufferEnd {
            let lo = Int(range.lowerBound - bufferStart)
            let hi = Int(range.upperBound - bufferStart)
            consume(buffer[lo ..< hi])
            return .success(())
        }

        // Read ahead from the source to fill the buffer.
        let readEnd = max(range.upperBound, range.lowerBound + UInt64(readAheadSize))
        var data = Data()
        let result = await source.stream(range: range.lowerBound ..< readEnd) {
            data.append($0)
        }

        guard case .success = result else {
            return result
        }

        buffer = data
        bufferStart = range.lowerBound

        let end = min(Int(range.count), data.count)
        if end > 0 {
            consume(data[0 ..< end])
        }
        return .success(())
    }
}
