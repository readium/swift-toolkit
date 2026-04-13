//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

public typealias CoverServiceFactory = (PublicationServiceContext) -> CoverService?

/// Provides an easy access to a bitmap version of the publication cover.
///
/// While at first glance, getting the cover could be seen as a helper, the
/// implementation actually depends on the publication format:
///
///  - Some might allow vector images or even HTML pages, in which case they
///    need to be converted to bitmaps.
///  - Others require to render the cover from a specific file format, e.g. PDF.
///
/// Furthermore, a reading app might want to use a custom strategy to choose the
/// cover image, for example by:
///
/// - iterating through the images collection for a publication parsed from an
///   OPDS 2 feed
/// - generating a bitmap from scratch using the publication's title
/// - using a cover selected by the user
public protocol CoverService: PublicationService {
    /// Returns the publication cover as a bitmap at its largest size.
    ///
    /// If the cover is not a bitmap format (e.g. SVG), it will be rendered at
    /// its intrinsic size, or scaled down to a reasonable maximum to avoid
    /// excessive memory usage.
    func cover() async -> ReadResult<UIImage?>

    /// Returns the publication cover as a bitmap scaled down to fit within
    /// `maxSize` pixels, preserving the aspect ratio without upscaling.
    ///
    /// Pass `pointSize * screenScale` to generate a device-sharp thumbnail.
    func coverFitting(maxSize: CGSize) async -> ReadResult<UIImage?>

    /// Returns the raw bytes and media type of the largest publication cover,
    /// if it is available in one of the accepted media types.
    ///
    /// This is useful when you want to store the original cover while retaining
    /// the original compression and encoding. The media types in `accepting`
    /// are listed in order of preference; the first one matched by a cover
    /// resource is returned. Note that type preference takes priority over
    /// link-list order.
    ///
    /// Returns `nil` if the cover is not natively available in any of the
    /// accepted media types, or if reading the cover resource fails. In that
    /// case, fall back to ``cover()`` to obtain a bitmap.
    @_spi(Experimental)
    func coverData(accepting mediaTypes: [MediaType]) async throws(ReadError) -> (data: Data, mediaType: MediaType)?
}

public extension CoverService {
    func coverFitting(maxSize: CGSize) async -> ReadResult<UIImage?> {
        await cover().map { $0?.scaleToFit(maxSize: maxSize) }
    }

    @_spi(Experimental)
    func coverData(accepting mediaTypes: [MediaType]) async throws(ReadError) -> (data: Data, mediaType: MediaType)? {
        nil
    }
}

// MARK: Publication Helpers

public extension Publication {
    /// Returns the publication cover as a bitmap at its largest size.
    ///
    /// If the cover is not a bitmap format (e.g. SVG), it will be rendered at
    /// its intrinsic size, or scaled down to a reasonable maximum to avoid
    /// excessive memory usage.
    func cover() async -> ReadResult<UIImage?> {
        guard let service = findService(CoverService.self) else {
            return .success(nil)
        }
        return await service.cover()
    }

    /// Returns the publication cover as a bitmap scaled down to fit within
    /// `maxSize` pixels, preserving the aspect ratio without upscaling.
    ///
    /// Pass `pointSize * screenScale` to generate a device-sharp thumbnail.
    func coverFitting(maxSize: CGSize) async -> ReadResult<UIImage?> {
        guard let service = findService(CoverService.self) else {
            return .success(nil)
        }
        return await service.coverFitting(maxSize: maxSize)
    }

    /// Returns the raw bytes and media type of the largest publication cover,
    /// if it is available in one of the accepted media types.
    ///
    /// This is useful when you want to store the original cover while retaining
    /// the original compression and encoding. The media types in `accepting`
    /// are listed in order of preference; the first one matched by a cover
    /// resource is returned. Note that type preference takes priority over
    /// link-list order.
    ///
    /// Returns `nil` if the cover is not natively available in any of the
    /// accepted media types, or if reading the cover resource fails. In that
    /// case, fall back to ``cover()`` to obtain a bitmap.
    @_spi(Experimental)
    func coverData(accepting mediaTypes: [MediaType]) async throws(ReadError) -> (data: Data, mediaType: MediaType)? {
        guard let service = findService(CoverService.self) else {
            return nil
        }
        return try await service.coverData(accepting: mediaTypes)
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
