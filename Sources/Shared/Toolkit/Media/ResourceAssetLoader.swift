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

        /// Resource read to serve the asset.
        package let resource: Resource

        /// Media type of the resource, which gives the content type of the
        /// asset. The file extension of the HREF is never used for it.
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

    /// Returns the normalized HREF of the resource served at the given asset
    /// URL, or `nil` when it is not the URL of an asset created by
    /// `makeAsset(for:)`.
    static func href(forAssetURL assetURL: URL) -> AnyURL? {
        guard let url = assetURL.anyURL.absoluteURL, url.scheme.rawValue.hasPrefix(schemePrefix) else {
            return nil
        }

        // The URL can be either:
        // * readium:relative/file.mp3
        // * readiumfile:///directory/local-file.mp3
        // * readiumhttp(s)://domain.com/external-file.mp3
        return AnyURL(string: url.string.removingPrefix(schemePrefix).removingPrefix(":"))?.normalized
    }

    // MARK: - Invalidation

    /// Whether `invalidate()` was called. The loader then refuses every
    /// request.
    private var isInvalidated = false

    /// Cancels the in-flight requests and returns once their streams have
    /// stopped. The loader no longer serves any resource afterwards.
    package func invalidate() async {
        let served = await queue.run { [self] in
            isInvalidated = true
            resources = [:]

            // The tasks remove themselves from `servedRequests` when they
            // end.
            let served = Array(servedRequests.values)
            for request in served {
                request.task.cancel()
            }
            return served
        }

        for request in served {
            await request.task.value
        }

        // A cancelled task leaves its request open. Failing it only now makes
        // sure that the task is done responding to it. A task which ended
        // before being cancelled finished its request already.
        await queue.run {
            for request in served where !request.loadingRequest.isFinished && !request.loadingRequest.isCancelled {
                request.loadingRequest.finishLoading(with: ReadError.cancelled)
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
        resources = resources.filter { href, _ in
            servedRequests.values.contains { $0.openDataHREF == href }
        }

        resources[href] = entry
        return entry
    }

    // MARK: - Requests Management

    /// A loading request with the task serving it.
    private struct ServedRequest {
        let loadingRequest: AVAssetResourceLoadingRequest
        let task: Task<Void, Never>

        /// HREF of the asset, for a data request which is still open: neither
        /// finished nor abandoned by the player.
        var openDataHREF: AnyURL?
    }

    /// Requests whose task did not end yet.
    ///
    /// A task can outlive its request: the stream of a data request abandoned
    /// by the player only stops once it notices its cancellation.
    private var servedRequests: [UUID: ServedRequest] = [:]

    /// Serves `request` with `operation`, in a task tracked in
    /// `servedRequests` until it ends.
    ///
    /// - Parameter dataHREF: HREF of the asset for a data request, `nil` for
    ///   a content information request.
    private func serve(
        _ request: AVAssetResourceLoadingRequest,
        dataHREF: AnyURL? = nil,
        operation: @escaping @Sendable () async -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(queue))

        let id = UUID()
        let task = Task { [self] in
            await operation()
            queue.async { [self] in
                servedRequests.removeValue(forKey: id)
            }
        }
        servedRequests[id] = ServedRequest(loadingRequest: request, task: task, openDataHREF: dataHREF)
    }

    /// Closes the given data request, cancelling its task if necessary.
    ///
    /// A content information request is left alone. Its task is only
    /// cancelled by `invalidate()`, as a resource usually caches its length
    /// for the next requests.
    private func finishRequest(_ request: AVAssetResourceLoadingRequest) {
        dispatchPrecondition(condition: .onQueue(queue))

        guard let id = servedRequests.first(where: { $0.value.loadingRequest == request && $0.value.openDataHREF != nil })?.key else {
            return
        }

        // The resource is intentionally kept in `resources`, to reuse its
        // buffered data with the next loading requests for the same entry.
        servedRequests[id]?.task.cancel()
        servedRequests[id]?.openDataHREF = nil
    }

    // MARK: - AVAssetResourceLoaderDelegate

    package func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard
            !isInvalidated,
            let href = loadingRequest.request.url.flatMap(Self.href(forAssetURL:)),
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
        serve(request) { [self] in
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

        serve(request, dataHREF: requestHREF) { [self] in
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

private extension DispatchQueue {
    /// Runs `work` on the queue and returns its result.
    func run<T>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            async {
                continuation.resume(returning: work())
            }
        }
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
