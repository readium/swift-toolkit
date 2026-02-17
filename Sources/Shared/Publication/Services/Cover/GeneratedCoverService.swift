//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

/// A `CoverService` which holds a lazily generated cover bitmap in memory.
public actor GeneratedCoverService: CoverService {
    enum Error: Swift.Error {
        case generationFailed
    }

    private var _cover: ReadResult<UIImage>?
    private let makeCover: @Sendable () async -> ReadResult<UIImage>

    public init(makeCover: @escaping @Sendable () async -> ReadResult<UIImage>) {
        self.makeCover = makeCover
    }

    public init(cover: UIImage) {
        self.init(makeCover: { .success(cover) })
    }

    private nonisolated let coverLink = Link(
        href: "~readium/cover",
        mediaType: .png,
        rel: .cover
    )

    private func cachedCover() async -> ReadResult<UIImage> {
        if let cover = _cover {
            return cover
        }
        
        let newCover = await makeCover()
        _cover = newCover
        return newCover
    }

    public func cover() async -> ReadResult<UIImage?> {
        await cachedCover().map { $0 as UIImage? }
    }

    public nonisolated var links: [Link] {
        [coverLink]
    }

    public nonisolated func get<T: URLConvertible>(_ href: T) -> (any Resource)? {
        guard href.anyURL.isEquivalentTo(coverLink.url()) else {
            return nil
        }

        return CoverResource(service: self)
    }

    public static func makeFactory(makeCover: @escaping @Sendable () async -> ReadResult<UIImage>) -> CoverServiceFactory {
        { _ in GeneratedCoverService(makeCover: makeCover) }
    }

    public static func makeFactory(cover: UIImage) -> CoverServiceFactory {
        { _ in GeneratedCoverService(cover: cover) }
    }

    private final class CoverResource: Resource, Sendable {
        private let service: GeneratedCoverService

        init(service: GeneratedCoverService) {
            self.service = service
        }

        let sourceURL: AbsoluteURL? = nil

        func estimatedLength() async -> ReadResult<UInt64?> {
            .success(nil)
        }

        func properties() async -> ReadResult<ResourceProperties> {
            .success(ResourceProperties())
        }

        func stream(range: Range<UInt64>?, consume: @escaping @Sendable (Data) -> Void) async -> ReadResult<Void> {
            await service.cachedCover().flatMap {
                guard let data = $0.pngData() else {
                    return .failure(.decoding("Failed to convert the cover bitmap to PNG data"))
                }
                consume(data)
                return .success(())
            }
        }
    }
}
