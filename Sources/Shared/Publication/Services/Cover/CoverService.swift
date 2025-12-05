//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

public typealias CoverServiceFactory = (PublicationServiceContext) -> CoverService?

/// Provides an easy access to a bitmap version of the publication cover.
///
/// While at first glance, getting the cover could be seen as a helper, the implementation
/// actually depends on the publication format:
///
///  - Some might allow vector images or even HTML pages, in which case they need to be converted
///    to bitmaps.
///  - Others require to render the cover from a specific file format, e.g. PDF.
///
/// Furthermore, a reading app might want to use a custom strategy to choose the cover image, for
/// example by:
///
/// - iterating through the images collection for a publication parsed from an OPDS 2 feed
/// - generating a bitmap from scratch using the publication's title
/// - using a cover selected by the user
public protocol CoverService: PublicationService {
    /// Returns the publication cover as a bitmap at its maximum size.
    ///
    /// If the cover is not a bitmap format (e.g. SVG), it will be scaled down to fit the screen
    /// using `UIScreen.main.bounds.size`.
    func cover() async -> ReadResult<UIImage?>

    /// Returns the publication cover as a bitmap, scaled down to fit the given `maxSize`.
    ///
    /// If the cover is not in a bitmap format (e.g. SVG), it is exported as a bitmap filling
    /// `maxSize`. The cover might be cached in memory for next calls.
    func coverFitting(maxSize: CGSize) async -> ReadResult<UIImage?>
}

public extension CoverService {
    func coverFitting(maxSize: CGSize) async -> ReadResult<UIImage?> {
        await cover().map { $0?.scaleToFit(maxSize: maxSize) }
    }
}

// MARK: Publication Helpers

public extension Publication {
    /// Returns the publication cover as a bitmap at its maximum size.
    func cover() async -> ReadResult<UIImage?> {
        if let service = findService(CoverService.self) {
            return await service.cover()
        } else {
            return await coverFromManifest()
        }
    }

    /// Returns the publication cover as a bitmap, scaled down to fit the given `maxSize`.
    func coverFitting(maxSize: CGSize) async -> ReadResult<UIImage?> {
        if let service = findService(CoverService.self) {
            return await service.coverFitting(maxSize: maxSize)
        } else {
            return await coverFromManifest()
                .map { $0?.scaleToFit(maxSize: maxSize) }
        }
    }

    /// Extracts the first valid cover from the manifest links with `cover` relation.
    private func coverFromManifest() async -> ReadResult<UIImage?> {
        for link in linksWithRel(.cover) {
            guard let image = await get(link)?
                .read().getOrNil()
                .flatMap({ UIImage(data: $0) })
            else {
                continue
            }
            return .success(image)
        }
        return .success(nil)
    }
}

// MARK: PublicationServicesBuilder Helpers

public extension PublicationServicesBuilder {
    mutating func setCoverServiceFactory(_ factory: CoverServiceFactory?) {
        if let factory = factory {
            set(CoverService.self, factory)
        } else {
            remove(CoverService.self)
        }
    }
}
