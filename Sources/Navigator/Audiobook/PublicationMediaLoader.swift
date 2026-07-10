//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import ReadiumShared

/// Serves `Publication`'s `Resource`s as an `AVURLAsset`.
///
/// Useful for local resources or when you need to customize the way HTTP requests are sent.
final class PublicationMediaLoader: NSObject, AVAssetResourceLoaderDelegate, Loggable, @unchecked Sendable {
    enum AssetError: Error {
        /// Can't produce an URL to create an AVAsset for the given HREF.
        case invalidHREF(String)
    }

    private let publication: Publication

    /// Called when a resource failed to be served to the player, e.g. to
    /// forward the error to the `NavigatorDelegate`.
    var onLoadingError: ((AnyURL, ReadError) -> Void)?

    private let tasks = CancellableTasks()

    init(publication: Publication) {
        self.publication = publication
    }

    private let queue = DispatchQueue(label: "org.readium.swift-toolkit.navigator.PublicationMediaLoader")

    /// Creates a new `AVURLAsset` to serve the given `link`.
    func makeAsset(for link: Link) throws -> AVURLAsset {
        let originalURL = link.url(relativeTo: publication.baseURL)
        guard var components = URLComponents(url: originalURL.url, resolvingAgainstBaseURL: true) else {
            throw AssetError.invalidHREF(link.href)
        }

        // If we don't use a custom scheme, the `AVAssetResourceLoaderDelegate` methods will never be called.
        components.scheme = schemePrefix + (components.scheme ?? "")
        guard let url = components.url else {
            throw AssetError.invalidHREF(link.href)
        }

        let asset = AVURLAsset(url: url)
        asset.resourceLoader.setDelegate(self, queue: queue)
        return asset
    }

    // MARK: - Resource Management

    private var resources: [AnyURL: (Link, Resource)] = [:]

    private func resource<T: URLConvertible>(forHREF href: T) -> (Link, Resource)? {
        dispatchPrecondition(condition: .onQueue(queue))

        let href = href.anyURL.normalized
        if let res = resources[href] {
            return res
        }

        guard
            let link = publication.linkWithHREF(href),
            let resource = publication.get(link)
        else {
            return nil
        }
        resources[href] = (link, resource)
        return (link, resource)
    }

    // MARK: - Requests Management

    private typealias CancellableRequest = (request: AVAssetResourceLoadingRequest, task: Task<Void, Never>)

    /// List of on-going loading requests.
    private var requests: [AnyURL: [CancellableRequest]] = [:]

    /// Adds a new loading request.
    private func registerRequest<T: URLConvertible>(_ request: AVAssetResourceLoadingRequest, task: Task<Void, Never>, for href: T) {
        dispatchPrecondition(condition: .onQueue(queue))

        let href = href.anyURL.normalized
        var reqs: [CancellableRequest] = requests[href] ?? []
        reqs.append((request, task))
        requests[href] = reqs
    }

    /// Terminates and removes the given loading request, cancelling it if necessary.
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

        if reqs.isEmpty {
            resources.removeValue(forKey: href)
            requests.removeValue(forKey: href)
        } else {
            requests[href] = reqs
        }
    }

    // MARK: - AVAssetResourceLoaderDelegate

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard
            let href = loadingRequest.request.url?.audioHREF,
            let (link, res) = resource(forHREF: href)
        else {
            return false
        }

        // According to https://jaredsinclair.com/2016/09/03/implementing-avassetresourceload.html, we should not
        // honor the `dataRequest` if there is a `contentInformationRequest`.
        //
        // > Warning: do not pass the two requested bytes of data to the loading request’s dataRequest. This will
        // > lead to an undocumented bug where no further loading requests will be made, stalling playback
        // > indefinitely.
        if let infoRequest = loadingRequest.contentInformationRequest {
            fillInfo(infoRequest, of: loadingRequest, using: res, link: link)
        } else if let dataRequest = loadingRequest.dataRequest {
            fillData(dataRequest, of: loadingRequest, using: res, link: link)
        }

        return true
    }

    private func fillInfo(
        _ infoRequest: AVAssetResourceLoadingContentInformationRequest,
        of request: AVAssetResourceLoadingRequest,
        using resource: Resource,
        link: Link
    ) {
        log(.info, "[#579] \(timestamp579()) contentInformationRequest for \(link.href)")

        tasks.add { [self] in
            infoRequest.isByteRangeAccessSupported = true
            infoRequest.contentType = link.mediaType?.uti

            switch await resource.length() {
            case let .success(length):
                infoRequest.contentLength = Int64(length)
                log(.info, "[#579] \(timestamp579()) contentInformationRequest fulfilled: contentLength=\(length), contentType=\(infoRequest.contentType ?? "nil"), byteRangeAccessSupported=true")
                request.finishLoading()

            case let .failure(error):
                log(.error, error)
                report(error, forHREF: link.url())
                request.finishLoading(with: error)
            }
        }
    }

    private func fillData(_ dataRequest: AVAssetResourceLoadingDataRequest, of request: AVAssetResourceLoadingRequest, using resource: Resource, link: Link) {
        let range: Range<UInt64>?
        if dataRequest.currentOffset == 0, dataRequest.requestsAllDataToEndOfResource {
            range = nil
        } else {
            range = UInt64(dataRequest.currentOffset) ..< (UInt64(dataRequest.currentOffset) + UInt64(dataRequest.requestedLength))
        }

        log(.info, "[#579] \(timestamp579()) dataRequest for \(link.href): currentOffset=\(dataRequest.currentOffset), requestedLength=\(dataRequest.requestedLength), requestsAllDataToEndOfResource=\(dataRequest.requestsAllDataToEndOfResource) -> range=\(range.map(String.init(describing:)) ?? "nil (full resource)")")

        let task = Task { [self] in
            var consumedBytes = 0
            var consumeCalls = 0
            let result = await resource.stream(
                range: range,
                consume: {
                    consumedBytes += $0.count
                    consumeCalls += 1
                    log(.info, "[#579] \(timestamp579()) consume #\(consumeCalls): chunk=\($0.count) bytes, total=\(consumedBytes) bytes")
                    dataRequest.respond(with: $0)
                }
            )

            queue.async { [weak self] in
                switch result {
                case .success:
                    self?.log(.info, "[#579] \(timestamp579()) dataRequest finished: \(consumeCalls) consume call(s), \(consumedBytes) bytes total")
                    request.finishLoading()
                case let .failure(error):
                    self?.log(.info, "[#579] \(timestamp579()) dataRequest failed after \(consumeCalls) consume call(s), \(consumedBytes) bytes: \(error)")
                    self?.report(error, forHREF: link.url())
                    request.finishLoading(with: error)
                }

                self?.finishRequest(request)
            }
        }

        registerRequest(request, task: task, for: link.url())
    }

    private func report(_ error: ReadError, forHREF href: AnyURL) {
        // Cancellation is not an error worth reporting, it occurs whenever
        // the player abandons a data request, e.g. when seeking.
        if case .cancelled = error {
            return
        }
        onLoadingError?(href, error)
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        log(.info, "[#579] \(timestamp579()) didCancel loadingRequest: offset=\(loadingRequest.dataRequest?.currentOffset ?? -1)")
        finishRequest(loadingRequest)
    }
}

/// Timestamp helper to correlate the [#579] diagnostic log events.
func timestamp579() -> String {
    String(format: "t=%.3fs", CFAbsoluteTimeGetCurrent() - loadingStartTime579)
}

private let loadingStartTime579 = CFAbsoluteTimeGetCurrent()

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

extension Resource {
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
