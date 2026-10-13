//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

/// A `CoverService` which holds the encoded bytes of a cover in memory, such
/// as an image embedded in the tags of an audio file.
public final class EmbeddedCoverService: CoverService, Sendable {
    private let data: Data
    private let mediaType: MediaType?
    private let cachedCover: AsyncMemoizer<UIImage?>
    private let coverLink: Link

    /// - Parameters:
    ///   - data: Encoded bytes of the cover image.
    ///   - mediaType: Media type declared for `data`, if any. It is trusted
    ///     and not verified against the content.
    public init(data: Data, mediaType: MediaType?) {
        self.data = data
        self.mediaType = mediaType
        cachedCover = AsyncMemoizer { UIImage(data: data) }
        coverLink = Link(
            href: "~readium/cover",
            mediaType: mediaType,
            rel: .cover
        )
    }

    public func cover() async -> ReadResult<UIImage?> {
        await .success(cachedCover())
    }

    public func coverData(accepting mediaTypes: [MediaType]) async throws(ReadError) -> (data: Data, mediaType: MediaType)? {
        guard
            let mediaType,
            mediaTypes.contains(where: { mediaType.matches($0) })
        else {
            return nil
        }
        return (data: data, mediaType: mediaType)
    }

    public var links: [Link] {
        [coverLink]
    }

    public func get<T: URLConvertible>(_ href: T) -> (any Resource)? {
        guard href.anyURL.isEquivalentTo(coverLink.url()) else {
            return nil
        }

        return DataResource { [data] in .success(data) }
    }

    public static func makeFactory(data: Data, mediaType: MediaType?) -> @Sendable (PublicationServiceContext) -> EmbeddedCoverService? {
        { _ in EmbeddedCoverService(data: data, mediaType: mediaType) }
    }
}
