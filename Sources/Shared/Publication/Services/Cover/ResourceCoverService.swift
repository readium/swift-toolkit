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
    /// Default maximum size in points for SVG cover rendering.
    private static let defaultCoverMaxSize = CGSize(width: 400, height: 600)

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

    private func loadCover(maxSize: CGSize?) async -> ReadResult<UIImage?> {
        // Try resources with explicit `cover` relation
        for link in context.manifest.linksWithRel(.cover) {
            if let image = await loadImage(from: link, maxSize: maxSize) {
                return .success(image)
            }
        }

        // Fallback: first reading order bitmap/SVG or alternate
        if let firstLink = context.manifest.readingOrder.first {
            if let image = await loadImage(from: firstLink, maxSize: maxSize) {
                return .success(image)
            }

            for alternate in firstLink.alternates {
                if let image = await loadImage(from: alternate, maxSize: maxSize) {
                    return .success(image)
                }
            }
        }

        return .success(nil)
    }

    private func loadImage(from link: Link, maxSize: CGSize?) async -> UIImage? {
        guard
            let mediaType = link.mediaType,
            mediaType.isBitmap || mediaType.matches(.svg),
            let resource = context.container[link.url()],
            let data = try? await resource.read().get()
        else {
            return nil
        }

        if mediaType.matches(.svg) {
            return UIImage.fromSVG(data, maxSize: maxSize ?? Self.defaultCoverMaxSize)
        }

        let image = UIImage(data: data)
        if let maxSize = maxSize {
            return image?.scaleToFit(maxSize: maxSize)
        }
        return image
    }

    public static func makeFactory() -> (PublicationServiceContext) -> ResourceCoverService {
        { ResourceCoverService(context: $0) }
    }
}
