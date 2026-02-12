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

        let result = await resource.read()
        switch result {
        case let .success(data):
            let mediaType = link?.mediaType?.string ?? "application/octet-stream"
            await respond(urlSchemeTask, with: data, mimeType: mediaType, url: requestURL)

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
        let result = await resource.read()
        switch result {
        case let .success(data):
            let mimeType = file.pathExtension
                .flatMap { UTType(filenameExtension: $0.rawValue)?.preferredMIMEType }
                ?? "application/octet-stream"
            await respond(urlSchemeTask, with: data, mimeType: mimeType, url: requestURL)

        case let .failure(error):
            log(.error, "Failed to read file \(file): \(error)")
            await fail(urlSchemeTask, with: URLError(.fileDoesNotExist))
        }
    }

    // MARK: - Response helpers

    private func respond(
        _ urlSchemeTask: WKURLSchemeTask,
        with data: Data,
        mimeType: String,
        url: URL
    ) async {
        let response = URLResponse(
            url: url,
            mimeType: mimeType,
            expectedContentLength: data.count,
            textEncodingName: nil
        )

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
}
