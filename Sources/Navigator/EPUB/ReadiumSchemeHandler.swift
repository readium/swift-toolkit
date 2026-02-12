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
final class ReadiumSchemeHandler: NSObject, WKURLSchemeHandler, Loggable {
    let scheme = "readium"

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
        publication: Publication?,
        publicationBaseURL: AbsoluteURL?,
        assetsBaseURL: AbsoluteURL,
        assetsDirectory: FileURL
    ) {
        precondition(
            publication == nil || publicationBaseURL != nil,
            "publicationBaseURL is required when publication is provided"
        )
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
                self?.activeTasks.removeValue(forKey: taskID)
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

        // Get the resource from the publication.
        guard var resource = publication.get(relativeURL) else {
            await fail(urlSchemeTask, with: URLError(.fileDoesNotExist))
            return
        }

        // Apply resource transformers.
        let href = relativeURL.anyURL
        for transformer in transformers {
            resource = transformer(href, resource)
        }

        let mediaType = link?.mediaType?.string ?? "application/octet-stream"

        // Try to serve a byte range if the client requested one and the
        // resource length is known.
        if let totalLength = await (try? resource.estimatedLength().get()).flatMap({ $0 }),
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
