//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

/// A `CoverService` which holds a lazily generated cover bitmap in memory.
public final class GeneratedCoverService: CoverService, @unchecked Sendable {
    enum Error: Swift.Error {
        case generationFailed
    }

    private let lock = NSLock()
    private var _cover: ReadResult<UIImage>?
    private let makeCover: @Sendable () async -> ReadResult<UIImage>

    public init(makeCover: @escaping @Sendable () async -> ReadResult<UIImage>) {
        self.makeCover = makeCover
    }

    public convenience init(cover: UIImage) {
        self.init(makeCover: { .success(cover) })
    }

    private let coverLink = Link(
        href: "~readium/cover",
        mediaType: .png,
        rel: .cover
    )

    private func cachedCover() async -> ReadResult<UIImage> {
        let cover: ReadResult<UIImage>? = lock.withLock { _cover }
        if let cover = cover {
            return cover
        }
        
        let newCover = await makeCover()
        lock.withLock { _cover = newCover }
        return newCover
    }

    public func cover() async -> ReadResult<UIImage?> {
        await cachedCover().map { $0 as UIImage? }
    }

    public var links: [Link] { [coverLink] }

    public func get<T>(_ href: T) -> (any Resource)? where T: URLConvertible {
        guard href.anyURL.isEquivalentTo(coverLink.url()) else {
            return nil
        }

        return CoverResource(cover: cachedCover)
    }

    public static func makeFactory(makeCover: @escaping @Sendable () async -> ReadResult<UIImage>) -> CoverServiceFactory {
        { _ in GeneratedCoverService(makeCover: makeCover) }
    }

    public static func makeFactory(cover: UIImage) -> CoverServiceFactory {
        { _ in GeneratedCoverService(cover: cover) }
    }

    private class CoverResource: Resource, @unchecked Sendable {
        private let cover: @Sendable () async -> ReadResult<UIImage>

        public init(cover: @escaping @Sendable () async -> ReadResult<UIImage>) {
            self.cover = cover
        }

        let sourceURL: AbsoluteURL? = nil

        func estimatedLength() async -> ReadResult<UInt64?> {
            .success(nil)
        }

        func properties() async -> ReadResult<ResourceProperties> {
            .success(ResourceProperties())
        }

        func stream(range: Range<UInt64>?, consume: @escaping @Sendable (Data) -> Void) async -> ReadResult<Void> {
            await cover().flatMap {
                guard let data = $0.pngData() else {
                    return .failure(.decoding("Failed to convert the cover bitmap to PNG data"))
                }
                consume(data)
                return .success(())
            }
        }
    }
}
