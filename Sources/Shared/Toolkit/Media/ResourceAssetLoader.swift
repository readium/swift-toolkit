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

    /// Queue on which the requests are received and the loader state is
    /// accessed.
    let queue = DispatchQueue(label: "org.readium.swift-toolkit.ResourceAssetLoader")

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
        let loadingRequest: any AssetLoadingRequest
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
        _ request: any AssetLoadingRequest,
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
    private func finishRequest(_ request: any AssetLoadingRequest) {
        dispatchPrecondition(condition: .onQueue(queue))

        guard let id = servedRequests.first(where: { $0.value.loadingRequest.id == request.id && $0.value.openDataHREF != nil })?.key else {
            return
        }

        // The resource is intentionally kept in `resources`, to reuse its
        // buffered data with the next loading requests for the same entry.
        servedRequests[id]?.task.cancel()
        servedRequests[id]?.openDataHREF = nil
    }

    // MARK: - Loading Requests

    /// Starts serving `request`, or returns false when the loader does not
    /// serve its asset.
    func load(_ request: any AssetLoadingRequest) -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))

        guard
            !isInvalidated,
            let href = request.url.flatMap(Self.href(forAssetURL:)),
            let entry = entry(forHREF: href)
        else {
            return false
        }

        switch request.kind {
        case .contentInformation:
            fillInfo(of: request, using: entry)
        case let .data(offset, length, toEnd):
            let range: Range<UInt64>? = (offset == 0 && toEnd)
                ? nil
                : UInt64(offset) ..< (UInt64(offset) + UInt64(length))
            fillData(of: request, range: range, using: entry, requestHREF: href)
        case nil:
            break
        }

        return true
    }

    /// Stops serving `request`, abandoned by the player.
    func cancel(_ request: any AssetLoadingRequest) {
        finishRequest(request)
    }

    private func fillInfo(of request: any AssetLoadingRequest, using entry: Entry) {
        serve(request) { [self] in
            let result = await entry.resource.length()

            // Only `invalidate()` cancels the task, and it fails the request
            // itself once the task ended.
            guard !Task.isCancelled else {
                return
            }

            switch result {
            case let .success(length):
                request.setContentInformation(contentType: entry.mediaType?.uti, contentLength: Int64(length))
                request.finishLoading(with: nil)

            case let .failure(error):
                log(.error, error)
                report(error, forHREF: entry.href)
                request.finishLoading(with: error)
            }
        }
    }

    /// - Parameter range: Range of the resource to serve, `nil` for the whole
    ///   resource.
    private func fillData(
        of request: any AssetLoadingRequest,
        range: Range<UInt64>?,
        using entry: Entry,
        requestHREF: AnyURL
    ) {
        serve(request, dataHREF: requestHREF) { [self] in
            let result = await entry.resource.stream(
                range: range,
                consume: { request.respond(with: $0) }
            )

            // The player abandons data requests regularly, e.g. when seeking.
            // There's nothing to report or finish in this case.
            guard !Task.isCancelled else {
                return
            }

            queue.async { [weak self] in
                switch result {
                case .success:
                    request.finishLoading(with: nil)
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

    // MARK: - AVAssetResourceLoaderDelegate

    package func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        load(AVFoundationLoadingRequest(loadingRequest))
    }

    package func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        cancel(AVFoundationLoadingRequest(loadingRequest))
    }
}

/// A request of the player to a `ResourceAssetLoader`.
///
/// Abstracts `AVAssetResourceLoadingRequest`, to test the loader without
/// AVFoundation.
protocol AssetLoadingRequest: AnyObject, Sendable {
    /// Identifies the request across the callbacks of the player.
    var id: ObjectIdentifier { get }

    /// URL of the requested asset.
    var url: URL? { get }

    /// What the player asks for, `nil` for nothing the loader serves.
    var kind: AssetLoadingRequestKind? { get }

    /// Whether the loader finished the request.
    var isFinished: Bool { get }

    /// Whether the player abandoned the request.
    var isCancelled: Bool { get }

    /// Answers a content information request.
    func setContentInformation(contentType: String?, contentLength: Int64)

    /// Delivers the next bytes of a data request.
    func respond(with data: Data)

    /// Finishes the request, with `error` when it failed.
    func finishLoading(with error: (any Error)?)
}

/// What the player asks for in an `AssetLoadingRequest`.
enum AssetLoadingRequestKind: Equatable {
    /// The type and length of the resource.
    case contentInformation

    /// `length` bytes from `offset`, or every byte from `offset` when
    /// `toEnd` is true.
    case data(offset: Int64, length: Int, toEnd: Bool)
}

/// An `AVAssetResourceLoadingRequest` as an `AssetLoadingRequest`.
///
/// Unchecked, as the tasks of the loader respond to the request.
private final class AVFoundationLoadingRequest: AssetLoadingRequest, @unchecked Sendable {
    private let request: AVAssetResourceLoadingRequest

    init(_ request: AVAssetResourceLoadingRequest) {
        self.request = request
    }

    var id: ObjectIdentifier {
        ObjectIdentifier(request)
    }

    var url: URL? {
        request.request.url
    }

    var kind: AssetLoadingRequestKind? {
        // According to https://jaredsinclair.com/2016/09/03/implementing-avassetresourceload.html,
        // we should not honor the `dataRequest` if there is a
        // `contentInformationRequest`.
        //
        // > Warning: do not pass the two requested bytes of data to the loading
        // > request’s dataRequest. This will lead to an undocumented bug where
        // > no further loading requests will be made, stalling playback
        // > indefinitely.
        if request.contentInformationRequest != nil {
            return .contentInformation
        }
        guard let dataRequest = request.dataRequest else {
            return nil
        }
        return .data(
            offset: dataRequest.currentOffset,
            length: dataRequest.requestedLength,
            toEnd: dataRequest.requestsAllDataToEndOfResource
        )
    }

    var isFinished: Bool {
        request.isFinished
    }

    var isCancelled: Bool {
        request.isCancelled
    }

    func setContentInformation(contentType: String?, contentLength: Int64) {
        guard let infoRequest = request.contentInformationRequest else {
            return
        }
        infoRequest.isByteRangeAccessSupported = true
        infoRequest.contentType = contentType
        infoRequest.contentLength = contentLength
    }

    func respond(with data: Data) {
        request.dataRequest?.respond(with: data)
    }

    func finishLoading(with error: (any Error)?) {
        if let error {
            request.finishLoading(with: error)
        } else {
            request.finishLoading()
        }
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
