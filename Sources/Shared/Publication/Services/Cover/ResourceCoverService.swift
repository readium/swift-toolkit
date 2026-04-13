//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

/// A `CoverService` which retrieves the cover from the publication container.
///
/// It will look for:
/// 1. Links with explicit `cover` relation in the resources.
/// 2. First `readingOrder` resource if it's a bitmap or SVG, or if it has a
///    bitmap/SVG `alternates`.
public final class ResourceCoverService: CoverService {
    /// Default maximum size in pixels for SVG cover rendering.
    private static let defaultCoverMaxSize = CGSize(width: 800, height: 1200)

    private let context: PublicationServiceContext

    public init(context: PublicationServiceContext) {
        self.context = context
    }

    public func cover() async -> ReadResult<UIImage?> {
        await loadCover(maxSize: nil)
    }

    public func coverFitting(maxSize: CGSize) async -> ReadResult<UIImage?> {
        await loadCover(maxSize: maxSize)
    }

    public func coverData(accepting mediaTypes: [MediaType]) async throws(ReadError) -> (data: Data, mediaType: MediaType)? {
        let links = coverLinks()
        for mediaType in mediaTypes {
            for link in links {
                guard
                    let linkMediaType = link.mediaType,
                    linkMediaType.matches(mediaType),
                    let result = await readData(from: link)
                else {
                    continue
                }
                return result
            }
        }
        return nil
    }

    /// Returns all candidate cover links in priority order:
    /// 1. Links with explicit `.cover` relation.
    /// 2. First reading-order link if it is a bitmap or SVG.
    /// 3. Bitmap/SVG alternates of the first reading-order link.
    private func coverLinks() -> [Link] {
        var links = context.manifest.linksWithRel(.cover)
        if !links.isEmpty {
            return links
        }

        if let firstLink = context.manifest.readingOrder.first {
            if firstLink.mediaType.isSupportedImage {
                links.append(firstLink)
            }
            links.append(contentsOf: firstLink.alternates.filter(\.mediaType.isSupportedImage))
        }

        return links
    }

    /// Reads the raw bytes from a cover link, returning `nil` if the resource
    /// cannot be read.
    private func readData(from link: Link) async -> (data: Data, mediaType: MediaType)? {
        guard
            let mediaType = link.mediaType,
            let resource = context.container[link.url()],
            let data = try? await resource.read().get()
        else {
            return nil
        }
        return (data: data, mediaType: mediaType)
    }

    private func loadCover(maxSize: CGSize?) async -> ReadResult<UIImage?> {
        for link in coverLinks() {
            if let image = await loadImage(from: link, maxSize: maxSize) {
                return .success(image)
            }
        }
        return .success(nil)
    }

    private func loadImage(from link: Link, maxSize: CGSize?) async -> UIImage? {
        guard
            let (data, mediaType) = await readData(from: link),
            mediaType.isSupportedImage
        else {
            return nil
        }

        if mediaType.matches(.svg) {
            return UIImage.fromSVG(data, maxSize: maxSize ?? Self.defaultCoverMaxSize)
        }

        let image = UIImage(data: data)
        if let maxSize {
            return image?.scaleToFit(maxSize: maxSize)
        }

        return image
    }

    public static func makeFactory() -> (PublicationServiceContext) -> ResourceCoverService {
        { ResourceCoverService(context: $0) }
    }
}

private extension MediaType? {
    var isSupportedImage: Bool {
        self?.isSupportedImage ?? false
    }
}

private extension MediaType {
    var isSupportedImage: Bool {
        isBitmap || matches(.svg)
    }
}
