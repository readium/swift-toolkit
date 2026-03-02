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
/// 2. First `readingOrder` resource if it's a bitmap, or if it has a bitmap
///    `alternates`.
public final class ResourceCoverService: CoverService {
    private let context: PublicationServiceContext

    public init(context: PublicationServiceContext) {
        self.context = context
    }

    public func cover() async -> ReadResult<UIImage?> {
        // Try resources with explicit `cover` relation
        for link in context.manifest.linksWithRel(.cover) {
            if let image = await loadImage(from: link) {
                return .success(image)
            }
        }

        // Fallback: first reading order bitmap or alternate
        if let firstLink = context.manifest.readingOrder.first {
            if firstLink.mediaType?.isBitmap == true {
                if let image = await loadImage(from: firstLink) {
                    return .success(image)
                }
            }
            for alternate in firstLink.alternates {
                if alternate.mediaType?.isBitmap == true {
                    if let image = await loadImage(from: alternate) {
                        return .success(image)
                    }
                }
            }
        }

        return .success(nil)
    }

    private func loadImage(from link: Link) async -> UIImage? {
        guard
            let resource = context.container[link.url()],
            let data = try? await resource.read().get()
        else {
            return nil
        }
        return UIImage(data: data)
    }

    public static func makeFactory() -> (PublicationServiceContext) -> ResourceCoverService {
        { ResourceCoverService(context: $0) }
    }
}
