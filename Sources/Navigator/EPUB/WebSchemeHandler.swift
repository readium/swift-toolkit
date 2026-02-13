//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UniformTypeIdentifiers
import WebKit

/// A `WKURLSchemeHandler` serving publication resources and static assets
/// using a custom URL scheme (e.g. `readium://`).
///
/// URL routing:
///   - `readium://{pub-uuid}/path` - publication resource
///   - `readium://assets/path` - static asset from the framework bundle
///   - `readium://assets/fonts/{id}/file` - custom font file
@MainActor final class WebSchemeHandler: NSObject, WKURLSchemeHandler, Loggable {
    /// The custom scheme used to serve the content.
    let scheme: String

    /// Publication to serve resources from (nil for remote publications).
    private let publication: Publication?

    /// Base URL for publication resources (e.g. `readium://{uuid}/`).
    private let publicationBaseURL: AbsoluteURL?

    /// Base URL for static assets (`readium://assets/`).
    let assetsBaseURL: AbsoluteURL

    /// Local directory containing the framework's static assets.
    private let assetsDirectory: FileURL

    private var transformers: [ResourceTransformer] = []

    /// Registered custom font files, keyed by a unique path ID.
    @Atomic private var fontFiles: [String: FileURL] = [:]

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
    @Atomic private var resourceCache = BoundedResourceCache()

    /// - Parameters:
    ///   - publication: The publication to serve resources from, or `nil` for
    ///     remote publications that don't need local resource serving.
    ///   - publicationBaseURL: The base URL for publication resources (e.g.
    ///     `readium://{uuid}/`). Required when `publication` is non-nil.
    ///   - assetsBaseURL: The base URL for static assets (e.g.
    ///     `readium://assets/`).
    ///   - assetsDirectory: Local directory containing the framework's bundled
    ///     assets (Readium CSS, scripts, fonts).
    init(
        scheme: String,
        publication: Publication?,
        publicationBaseURL: AbsoluteURL?,
        assetsBaseURL: AbsoluteURL,
        assetsDirectory: FileURL
    ) {
        precondition(
            publication == nil || publicationBaseURL != nil,
            "publicationBaseURL is required when publication is provided"
        )
        self.scheme = scheme
        self.publication = publication
        self.publicationBaseURL = publicationBaseURL
        self.assetsBaseURL = assetsBaseURL
        self.assetsDirectory = assetsDirectory

        super.init()
    }

    /// Registers a resource transformer applied to all served publication
    /// resources.
    func transformResources(with transformer: @escaping ResourceTransformer) {
        transformers.append(transformer)
    }

    /// Registers a local font file and returns a URL that can be used to
    /// reference it from the web view.
    ///
    /// The returned URL has the form
    /// `readium://assets/fonts/{id}/{filename}`.
    func serveFont(at file: FileURL) -> AbsoluteURL {
        let id = UUID().uuidString
        $fontFiles.write { $0[id] = file }
        let fileName = file.lastPathSegment ?? "font"
        return assetsBaseURL
            .appendingPath("fonts", isDirectory: true)
            .appendingPath(id, isDirectory: true)
            .appendingPath(fileName, isDirectory: false)
    }

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

        // Route: assets (readium://assets/…)
        if let relativePath = assetsBaseURL.relativize(anyURL) {
            await serveAsset(urlSchemeTask, at: relativePath, requestURL: requestURL)
            return
        }

        // Route: publication resources (readium://{uuid}/…)
        guard
            let publicationBaseURL = publicationBaseURL,
            let publication = publication,
            let relativeURL = publicationBaseURL.relativize(anyURL)
        else {
            await fail(urlSchemeTask, with: URLError(.fileDoesNotExist))
            return
        }

        await servePublicationResource(
            urlSchemeTask,
            publication: publication,
            relativeURL: relativeURL,
            requestURL: requestURL
        )
    }

    /// Serves a publication resource.
    private func servePublicationResource(
        _ urlSchemeTask: WKURLSchemeTask,
        publication: Publication,
        relativeURL: RelativeURL,
        requestURL: URL
    ) async {
        // Look up the link for media type information.
        let link = publication.linkWithHREF(relativeURL)

        // Reuse a cached buffered resource to benefit from forward-seek
        // optimization and read-ahead buffering, or create and cache a new
        // one.
        let resource: BufferingResource
        if let cached = $resourceCache.read()[relativeURL] {
            resource = cached
        } else {
            guard var res: Resource = publication.get(relativeURL) else {
                await fail(urlSchemeTask, with: URLError(.fileDoesNotExist))
                return
            }
            let href = relativeURL.anyURL
            for transformer in transformers {
                res = transformer(href, res)
            }
            let buffered = BufferingResource(source: res)
            $resourceCache.write { $0.set(relativeURL, buffered) }
            resource = buffered
        }

        let mediaType = link?.mediaType?.string ?? "application/octet-stream"

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

    /// Serves a static asset or custom font file.
    private func serveAsset(
        _ urlSchemeTask: WKURLSchemeTask,
        at relativePath: RelativeURL,
        requestURL: URL
    ) async {
        let pathSegments = relativePath.pathSegments

        // Font files: fonts/{id}/filename
        if
            pathSegments.count >= 3,
            pathSegments[0] == "fonts"
        {
            let fontID = pathSegments[1]
            guard let file = fontFiles[fontID] else {
                await fail(urlSchemeTask, with: URLError(.fileDoesNotExist))
                return
            }
            await serveFile(urlSchemeTask, at: file, requestURL: requestURL)
            return
        }

        // Static assets from the bundle directory.
        let file = assetsDirectory.resolve(relativePath)
        guard let fileURL = file?.fileURL else {
            await fail(urlSchemeTask, with: URLError(.fileDoesNotExist))
            return
        }
        await serveFile(urlSchemeTask, at: fileURL, requestURL: requestURL)
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

    nonisolated var sourceURL: AbsoluteURL? { source.sourceURL }

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
