//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import WebKit

/// A `WKURLSchemeHandler` serving publication resources directly from a
/// `Publication` object using a custom URL scheme (e.g. `readium://`).
///
/// This replaces the HTTP server for serving publication resources to
/// `WKWebView`, while the HTTP server is still used for static assets.
final class PublicationSchemeHandler: NSObject, WKURLSchemeHandler, Loggable {
    let scheme = "readium"

    private let publication: Publication
    private let baseURL: AbsoluteURL
    private var transformers: [ResourceTransformer] = []

    /// Tracks active tasks for cancellation support.
    /// Only accessed from the main thread (WebKit calls start/stop on main).
    private var activeTasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    /// - Parameters:
    ///   - publication: The publication to serve resources from.
    ///   - baseURL: The base URL used to construct resource URLs (e.g.
    ///     `readium://{uuid}/`).
    init(publication: Publication, baseURL: AbsoluteURL) {
        self.publication = publication
        self.baseURL = baseURL
        super.init()
    }

    /// Registers a resource transformer applied to all served resources.
    func transformResources(with transformer: @escaping ResourceTransformer) {
        transformers.append(transformer)
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

        // Extract the relative href from the request URL.
        guard let relativeURL = baseURL.relativize(AnyURL(url: requestURL)) else {
            await fail(urlSchemeTask, with: URLError(.fileDoesNotExist))
            return
        }

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
            let response = URLResponse(
                url: requestURL,
                mimeType: mediaType,
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

        case let .failure(error):
            log(.error, "Failed to read resource \(relativeURL): \(error)")
            await fail(urlSchemeTask, with: URLError(.resourceUnavailable))
        }
    }

    private func fail(_ urlSchemeTask: WKURLSchemeTask, with error: Error) async {
        await MainActor.run {
            guard !Task.isCancelled else { return }
            urlSchemeTask.didFailWithError(error)
        }
    }
}
