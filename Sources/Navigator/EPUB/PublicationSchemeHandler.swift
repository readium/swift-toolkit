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
final class PublicationSchemeHandler: NSObject, WKURLSchemeHandler {
    let scheme = "readium"

    private let publication: Publication
    private let baseURL: AbsoluteURL
    private var transformers: [ResourceTransformer] = []

    /// Tracks active tasks for cancellation support.
    private var activeTasks: [ObjectIdentifier: SchemeTask] = [:]
    private let lock = NSLock()

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
        let task = SchemeTask(
            urlSchemeTask: urlSchemeTask,
            publication: publication,
            baseURL: baseURL,
            transformers: transformers
        )
        lock.lock()
        activeTasks[taskID] = task
        lock.unlock()

        task.start { [weak self] in
            self?.lock.lock()
            self?.activeTasks.removeValue(forKey: taskID)
            self?.lock.unlock()
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask)
        lock.lock()
        let task = activeTasks.removeValue(forKey: taskID)
        lock.unlock()
        task?.cancel()
    }
}

/// Manages a single URL scheme task: extracting the href, loading and
/// transforming the resource, and streaming data to the `WKURLSchemeTask`.
private final class SchemeTask: Loggable {
    private let urlSchemeTask: WKURLSchemeTask
    private let publication: Publication
    private let baseURL: AbsoluteURL
    private let transformers: [ResourceTransformer]

    /// Serial queue used to synchronize `WKURLSchemeTask` API calls.
    /// All calls to `didReceive(_:)`, `didFinish()`, and
    /// `didFailWithError(_:)` must be dispatched on this queue to prevent
    /// crashes when the task is cancelled concurrently.
    private let queue = DispatchQueue(label: "org.readium.navigator.scheme-task")
    private var isCancelled = false

    init(
        urlSchemeTask: WKURLSchemeTask,
        publication: Publication,
        baseURL: AbsoluteURL,
        transformers: [ResourceTransformer]
    ) {
        self.urlSchemeTask = urlSchemeTask
        self.publication = publication
        self.baseURL = baseURL
        self.transformers = transformers
    }

    func cancel() {
        queue.sync {
            isCancelled = true
        }
    }

    func start(completion: @escaping () -> Void) {
        Task {
            await run()
            completion()
        }
    }

    private func run() async {
        guard let requestURL = urlSchemeTask.request.url else {
            fail(with: URLError(.badURL))
            return
        }

        let requestAnyURL = AnyURL(url: requestURL)

        // Extract the relative href from the request URL.
        guard let relativeURL = baseURL.relativize(requestAnyURL) else {
            fail(with: URLError(.fileDoesNotExist))
            return
        }

        // Look up the link for media type information.
        let link = publication.linkWithHREF(relativeURL)

        // Get the resource from the publication.
        guard var resource = publication.get(relativeURL) else {
            fail(with: URLError(.fileDoesNotExist))
            return
        }

        // Apply resource transformers.
        let href = relativeURL.anyURL
        for transformer in transformers {
            resource = transformer(href, resource)
        }

        // Read the resource data.
        // We read the full data to get the correct content length, which is
        // necessary for WKURLSchemeTask.
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

            // Send the response and data chunks, guarding against
            // cancellation.
            let chunkSize = 32 * 1024 // 32 KB
            var offset = 0

            let shouldStop: Bool = queue.sync {
                guard !isCancelled else { return true }
                urlSchemeTask.didReceive(response)
                return false
            }
            if shouldStop { return }

            while offset < data.count {
                let end = min(offset + chunkSize, data.count)
                let chunk = data[offset ..< end]
                offset = end

                let stop: Bool = queue.sync {
                    guard !isCancelled else { return true }
                    urlSchemeTask.didReceive(chunk)
                    return false
                }
                if stop { return }
            }

            queue.sync {
                guard !isCancelled else { return }
                urlSchemeTask.didFinish()
            }

        case let .failure(error):
            log(.error, "Failed to read resource \(relativeURL): \(error)")
            fail(with: URLError(.resourceUnavailable))
        }
    }

    private func fail(with error: Error) {
        queue.sync {
            guard !isCancelled else { return }
            urlSchemeTask.didFailWithError(error)
        }
    }
}
