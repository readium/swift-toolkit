//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import ReadiumShared

/// Serves `Publication`'s `Resource`s as an `AVURLAsset`.
///
/// Useful for local resources or when you need to customize the way HTTP requests are sent.
final class PublicationMediaLoader: NSObject, AVAssetResourceLoaderDelegate {
    private typealias HREF = String

    public enum AssetError: LocalizedError {
        case invalidHREF(String)

        public var errorDescription: String? {
            switch self {
            case let .invalidHREF(href):
                return "Can't produce an URL to create an AVAsset for HREF \(href)"
            }
        }
    }

    private let publication: Publication

    init(publication: Publication) {
        self.publication = publication
    }

    private let queue = DispatchQueue(label: "org.readium.swift-toolkit.navigator.PublicationMediaLoader")

    /// Creates a new `AVURLAsset` to serve the given `link`.
    func makeAsset(for link: Link) throws -> AVURLAsset {
        guard
            let originalURL = try? link.url(relativeTo: publication.baseURL),
            var components = URLComponents(url: originalURL.url, resolvingAgainstBaseURL: true)
        else {
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

    private var resources: [HREF: (Link, Resource)] = [:]

    private func resource(forHREF href: HREF) -> (Link, Resource)? {
        if let res = resources[href] {
            return res
        }

        guard
            let link = publication.link(withHREF: href),
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
    private var requests: [HREF: [CancellableRequest]] = [:]

    /// Adds a new loading request.
    private func registerRequest(_ request: AVAssetResourceLoadingRequest, task: Task<Void, Never>, for href: HREF) {
        var reqs: [CancellableRequest] = requests[href] ?? []
        reqs.append((request, task))
        requests[href] = reqs
    }

    /// Terminates and removes the given loading request, cancelling it if necessary.
    private func finishRequest(_ request: AVAssetResourceLoadingRequest) {
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
            if let (_, res) = resources.removeValue(forKey: href) {
                res.close()
            }
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

    private func fillInfo(_ infoRequest: AVAssetResourceLoadingContentInformationRequest, of request: AVAssetResourceLoadingRequest, using resource: Resource, link: Link) {
        infoRequest.isByteRangeAccessSupported = true
        infoRequest.contentType = link.mediaType?.uti
        // FIXME:
        // if case let .success(length) = resource.length {
        //     infoRequest.contentLength = Int64(length)
        // }
        request.finishLoading()
    }

    private func fillData(_ dataRequest: AVAssetResourceLoadingDataRequest, of request: AVAssetResourceLoadingRequest, using resource: Resource, link: Link) {
        let range: Range<UInt64> = UInt64(dataRequest.currentOffset) ..< (UInt64(dataRequest.currentOffset) + UInt64(dataRequest.requestedLength))

        let task = Task {
            let result = await resource.stream(
                range: range,
                consume: { dataRequest.respond(with: $0) }
            )
            switch result {
            case .success:
                request.finishLoading()
            case let .failure(error):
                request.finishLoading(with: error)
            }
            self.finishRequest(request)
        }

        registerRequest(request, task: task, for: link.href)
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        finishRequest(loadingRequest)
    }
}

private let schemePrefix = "readium"

extension URL {
    var audioHREF: String? {
        guard let url = absoluteURL, url.scheme.rawValue.hasPrefix(schemePrefix) == true else {
            return nil
        }

        // The URL can be either:
        // * readium:relative/file.mp3
        // * readiumfile:///directory/local-file.mp3
        // * readiumhttp(s)://domain.com/external-file.mp3
        return url.string.removingPrefix(schemePrefix).removingPrefix(":")
    }
}
