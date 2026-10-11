//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation

/// Serves `Resource`s as `AVURLAsset`s.
///
/// Useful for local resources or when you need to customize the way HTTP
/// requests are sent.
package final class ResourceAssetLoader: NSObject, AVAssetResourceLoaderDelegate, Loggable, @unchecked Sendable {
    package enum AssetError: Error {
        /// Can't produce an URL to create an AVAsset for the given HREF.
        case invalidHREF(String)
    }

    /// A resource served by the loader.
    package struct Entry: Sendable {
        /// HREF identifying the resource.
        package let href: AnyURL
        package let resource: Resource
        package let mediaType: MediaType?

        package init(href: AnyURL, resource: Resource, mediaType: MediaType?) {
            self.href = href
            self.resource = resource
            self.mediaType = mediaType
        }
    }

    private let resolve: @Sendable (AnyURL) -> Entry?

    /// Called when a resource failed to be served, with the HREF of its
    /// entry.
    package var onLoadingError: ((AnyURL, ReadError) -> Void)?

    /// - Parameter resolve: Returns the resource to serve for the normalized
    ///   HREF of an asset, or `nil` when there is none.
    package init(resolve: @escaping @Sendable (AnyURL) -> Entry?) {
        self.resolve = resolve
    }

    private let queue = DispatchQueue(label: "org.readium.swift-toolkit.ResourceAssetLoader")

    /// Creates a new `AVURLAsset` to serve the resource at the given `url`.
    package func makeAsset(for url: AnyURL, options: [String: Any]? = nil) throws -> AVURLAsset {
        guard var components = URLComponents(url: url.url, resolvingAgainstBaseURL: true) else {
            throw AssetError.invalidHREF(url.string)
        }

        // If we don't use a custom scheme, the `AVAssetResourceLoaderDelegate`
        // methods will never be called.
        components.scheme = schemePrefix + (components.scheme ?? "")
        guard let assetURL = components.url else {
            throw AssetError.invalidHREF(url.string)
        }

        let asset = AVURLAsset(url: assetURL, options: options)
        asset.resourceLoader.setDelegate(self, queue: queue)
        return asset
    }

    // MARK: - Invalidation

    /// Whether `invalidate()` was called. The loader then refuses every
    /// request.
    private var isInvalidated = false

    /// Cancels the in-flight requests and returns once their streams have
    /// stopped. The loader no longer serves any resource afterwards.
    package func invalidate() async {
        let running: [CancellableRequest] = await withCheckedContinuation { continuation in
            queue.async { [self] in
                isInvalidated = true
                requests = [:]
                resources = [:]

                // The tasks remove themselves from `runningRequests` when
                // they end.
                let running = Array(runningRequests.values)
                for (_, task) in running {
                    task.cancel()
                }
                continuation.resume(returning: running)
            }
        }

        for (_, task) in running {
            await task.value
        }

        // A cancelled task leaves its request open. Failing it only now makes
        // sure that the task is done responding to it. A task which ended
        // before being cancelled finished its request already.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                for (request, _) in running where !request.isFinished && !request.isCancelled {
                    request.finishLoading(with: ReadError.cancelled)
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Resource Management

    private var resources: [AnyURL: Entry] = [:]

    private func entry(forHREF href: AnyURL) -> Entry? {
        dispatchPrecondition(condition: .onQueue(queue))

        if let entry = resources[href] {
            return entry
        }

        guard let entry = resolve(href) else {
            return nil
        }

        // Only the resources of other entries are evicted, as the player
        // routinely abandons its requests to issue new ones for the same
        // entry. Dropping the current resource would throw away its buffered
        // data and force re-downloading the beginning of the entry.
        resources = resources.filter { requests[$0.key] != nil }

        resources[href] = entry
        return entry
    }

    // MARK: - Requests Management

    private typealias CancellableRequest = (request: AVAssetResourceLoadingRequest, task: Task<Void, Never>)

    /// List of on-going data requests.
    private var requests: [AnyURL: [CancellableRequest]] = [:]

    /// Requests whose task did not end yet, for `invalidate()`.
    ///
    /// A task can outlive its request: the stream of a data request abandoned
    /// by the player only stops once it notices its cancellation. And the
    /// task of a content information request is only cancelled by
    /// `invalidate()`, as a resource usually caches its length for the next
    /// requests.
    private var runningRequests: [UUID: CancellableRequest] = [:]

    /// Serves `request` with `operation`, in a task tracked in
    /// `runningRequests` until it ends.
    private func serve(
        _ request: AVAssetResourceLoadingRequest,
        operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        dispatchPrecondition(condition: .onQueue(queue))

        let id = UUID()
        let task = Task { [self] in
            await operation()
            queue.async { [self] in
                runningRequests.removeValue(forKey: id)
            }
        }
        runningRequests[id] = (request, task)
        return task
    }

    /// Adds a new data request.
    private func registerRequest(_ request: AVAssetResourceLoadingRequest, task: Task<Void, Never>, for href: AnyURL) {
        dispatchPrecondition(condition: .onQueue(queue))

        var reqs: [CancellableRequest] = requests[href] ?? []
        reqs.append((request, task))
        requests[href] = reqs
    }

    /// Terminates and removes the given data request, cancelling it if
    /// necessary.
    private func finishRequest(_ request: AVAssetResourceLoadingRequest) {
        dispatchPrecondition(condition: .onQueue(queue))

        guard
            let href = request.request.url?.audioHREF,
            var reqs = requests[href],
            let index = reqs.firstIndex(where: { req, _ in req == request })
        else {
            return
        }

        let req = reqs.remove(at: index)
        req.task.cancel()

        // The resource is intentionally kept in `resources`, to reuse its
        // buffered data with the next loading requests for the same entry.
        if reqs.isEmpty {
            requests.removeValue(forKey: href)
        } else {
            requests[href] = reqs
        }
    }

    // MARK: - AVAssetResourceLoaderDelegate

    package func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard
            !isInvalidated,
            let href = loadingRequest.request.url?.audioHREF,
            let entry = entry(forHREF: href)
        else {
            return false
        }

        // According to https://jaredsinclair.com/2016/09/03/implementing-avassetresourceload.html,
        // we should not honor the `dataRequest` if there is a
        // `contentInformationRequest`.
        //
        // > Warning: do not pass the two requested bytes of data to the loading
        // > request’s dataRequest. This will lead to an undocumented bug where
        // > no further loading requests will be made, stalling playback
        // > indefinitely.
        if let infoRequest = loadingRequest.contentInformationRequest {
            fillInfo(infoRequest, of: loadingRequest, using: entry)
        } else if let dataRequest = loadingRequest.dataRequest {
            fillData(dataRequest, of: loadingRequest, using: entry, requestHREF: href)
        }

        return true
    }

    private func fillInfo(
        _ infoRequest: AVAssetResourceLoadingContentInformationRequest,
        of request: AVAssetResourceLoadingRequest,
        using entry: Entry
    ) {
        _ = serve(request) { [self] in
            infoRequest.isByteRangeAccessSupported = true
            infoRequest.contentType = entry.mediaType?.uti

            let result = await entry.resource.length()

            // Only `invalidate()` cancels the task, and it fails the request
            // itself once the task ended.
            guard !Task.isCancelled else {
                return
            }

            switch result {
            case let .success(length):
                infoRequest.contentLength = Int64(length)
                request.finishLoading()

            case let .failure(error):
                log(.error, error)
                report(error, forHREF: entry.href)
                request.finishLoading(with: error)
            }
        }
    }

    private func fillData(
        _ dataRequest: AVAssetResourceLoadingDataRequest,
        of request: AVAssetResourceLoadingRequest,
        using entry: Entry,
        requestHREF: AnyURL
    ) {
        let range: Range<UInt64>?
        if dataRequest.currentOffset == 0, dataRequest.requestsAllDataToEndOfResource {
            range = nil
        } else {
            range = UInt64(dataRequest.currentOffset) ..< (UInt64(dataRequest.currentOffset) + UInt64(dataRequest.requestedLength))
        }

        let task = serve(request) { [self] in
            let result = await entry.resource.stream(
                range: range,
                consume: { dataRequest.respond(with: $0) }
            )

            // The player abandons data requests regularly, e.g. when seeking.
            // There's nothing to report or finish in this case.
            guard !Task.isCancelled else {
                return
            }

            queue.async { [weak self] in
                switch result {
                case .success:
                    request.finishLoading()
                case let .failure(error):
                    self?.report(error, forHREF: entry.href)
                    request.finishLoading(with: error)
                }

                self?.finishRequest(request)
            }
        }

        registerRequest(request, task: task, for: requestHREF)
    }

    private func report(_ error: ReadError, forHREF href: AnyURL) {
        // Cancellation is not an error worth reporting, it occurs whenever
        // the player abandons a data request, e.g. when seeking.
        if case .cancelled = error {
            return
        }
        onLoadingError?(href, error)
    }

    package func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        finishRequest(loadingRequest)
    }
}

private let schemePrefix = "readium"

extension URL {
    var audioHREF: AnyURL? {
        guard let url = anyURL.absoluteURL, url.scheme.rawValue.hasPrefix(schemePrefix) == true else {
            return nil
        }

        // The URL can be either:
        // * readium:relative/file.mp3
        // * readiumfile:///directory/local-file.mp3
        // * readiumhttp(s)://domain.com/external-file.mp3
        return AnyURL(string: url.string.removingPrefix(schemePrefix).removingPrefix(":"))?.normalized
    }
}

private extension Resource {
    /// Returns the length of the resource, reading it whole when it is not
    /// known.
    func length() async -> ReadResult<UInt64> {
        await estimatedLength()
            .asyncFlatMap { length in
                if let length = length {
                    return .success(length)
                } else {
                    return await read().map { UInt64($0.count) }
                }
            }
    }
}
