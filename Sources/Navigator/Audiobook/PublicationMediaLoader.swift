//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import R2Shared

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

    private let queue = DispatchQueue(label: "org.readium.r2-navigator-swift.PublicationMediaLoader")

    /// Creates a new `AVURLAsset` to serve the given `link`.
    func makeAsset(for link: Link) throws -> AVURLAsset {
        let originalURL = link.url(relativeTo: publication.baseURL) ?? URL(fileURLWithPath: link.href)
        guard var components = URLComponents(url: originalURL, resolvingAgainstBaseURL: true) else {
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

    private var resources: [HREF: Resource] = [:]

    private func resource(forHREF href: HREF) -> Resource {
        if let res = resources[href] {
            return res
        }

        let res = publication.get(href)
        resources[href] = res
        return res
    }

    // MARK: - Requests Management

    private typealias CancellableRequest = (request: AVAssetResourceLoadingRequest, cancellable: Cancellable)

    /// List of on-going loading requests.
    private var requests: [HREF: [CancellableRequest]] = [:]

    /// Adds a new loading request.
    private func registerRequest(_ request: AVAssetResourceLoadingRequest, cancellable: Cancellable, for href: HREF) {
        var reqs: [CancellableRequest] = requests[href] ?? []
        reqs.append((request, cancellable))
        requests[href] = reqs
    }

    /// Terminates and removes the given loading request, cancelling it if necessary.
    private func finishRequest(_ request: AVAssetResourceLoadingRequest) {
        guard
            let href = request.href,
            var reqs = requests[href],
            let index = reqs.firstIndex(where: { req, _ in req == request })
        else {
            return
        }

        let req = reqs.remove(at: index)
        req.cancellable.cancel()

        if reqs.isEmpty {
            let res = resources.removeValue(forKey: href)
            res?.close()
            requests.removeValue(forKey: href)
        } else {
            requests[href] = reqs
        }
    }

    // MARK: - AVAssetResourceLoaderDelegate

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let href = loadingRequest.href else {
            return false
        }

        let res = resource(forHREF: href)

        // According to https://jaredsinclair.com/2016/09/03/implementing-avassetresourceload.html, we should not
        // honor the `dataRequest` if there is a `contentInformationRequest`.
        //
        // > Warning: do not pass the two requested bytes of data to the loading request’s dataRequest. This will
        // > lead to an undocumented bug where no further loading requests will be made, stalling playback
        // > indefinitely.
        if let infoRequest = loadingRequest.contentInformationRequest {
            fillInfo(infoRequest, of: loadingRequest, using: res)
        } else if let dataRequest = loadingRequest.dataRequest {
            fillData(dataRequest, of: loadingRequest, using: res)
        }

        return true
    }

    private func fillInfo(_ infoRequest: AVAssetResourceLoadingContentInformationRequest, of request: AVAssetResourceLoadingRequest, using resource: Resource) {
        infoRequest.isByteRangeAccessSupported = true
        infoRequest.contentType = resource.link.mediaType.uti
        if case let .success(length) = resource.length {
            infoRequest.contentLength = Int64(length)
        }
        request.finishLoading()
    }

    private func fillData(_ dataRequest: AVAssetResourceLoadingDataRequest, of request: AVAssetResourceLoadingRequest, using resource: Resource) {
        let range: Range<UInt64> = UInt64(dataRequest.currentOffset) ..< (UInt64(dataRequest.currentOffset) + UInt64(dataRequest.requestedLength))

        let cancellable = resource.stream(
            range: range,
            consume: { dataRequest.respond(with: $0) },
            completion: { result in
                switch result {
                case .success:
                    request.finishLoading()
                case let .failure(error):
                    request.finishLoading(with: error)
                }
                self.finishRequest(request)
            }
        )

        registerRequest(request, cancellable: cancellable, for: resource.link.href)
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        finishRequest(loadingRequest)
    }
}

private let schemePrefix = "r2"

private extension AVAssetResourceLoadingRequest {
    var href: String? {
        guard let url = request.url, url.scheme?.hasPrefix(schemePrefix) == true else {
            return nil
        }

        // The URL can be either:
        // * r2file://directory/local-file.mp3
        // * r2http(s)://domain.com/external-file.mp3
        switch url.scheme?.lowercased().removingPrefix(schemePrefix) {
        case "file":
            return url.path
        case "http", "https":
            return url.absoluteString.removingPrefix(schemePrefix)
        default:
            return nil
        }
    }
}
