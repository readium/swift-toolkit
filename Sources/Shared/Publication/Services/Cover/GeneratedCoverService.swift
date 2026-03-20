//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

/// A `CoverService` which holds a lazily generated cover bitmap in memory.
public final class GeneratedCoverService: CoverService {
    enum Error: Swift.Error {
        case generationFailed
    }

    private var _cover: Result<UIImage, ReadError>?
    private let makeCover: () async throws(ReadError) -> UIImage

    public init(makeCover: @escaping () async throws(ReadError) -> UIImage) {
        self.makeCover = makeCover
    }

    public convenience init(cover: UIImage) {
        self.init(makeCover: { cover })
    }

    private let coverLink = Link(
        href: "~readium/cover",
        mediaType: .png,
        rel: .cover
    )

    private func cachedCover() async throws(ReadError) -> UIImage {
        if _cover == nil {
            do {
                _cover = try await .success(makeCover())
            } catch {
                _cover = .failure(error)
            }
        }
        return try _cover!.get()
    }

    public func cover() async throws(ReadError) -> UIImage? {
        try await cachedCover() as UIImage?
    }

    public var links: [Link] {
        [coverLink]
    }

    public func get<T: URLConvertible>(_ href: T) -> (any Resource)? {
        guard href.anyURL.isEquivalentTo(coverLink.url()) else {
            return nil
        }

        return CoverResource(cover: cachedCover)
    }

    public static func makeFactory(makeCover: @escaping () async throws(ReadError) -> UIImage) -> (PublicationServiceContext) -> GeneratedCoverService? {
        { _ in GeneratedCoverService(makeCover: makeCover) }
    }

    public static func makeFactory(cover: UIImage) -> (PublicationServiceContext) -> GeneratedCoverService? {
        { _ in GeneratedCoverService(cover: cover) }
    }

    private class CoverResource: Resource {
        private let cover: () async throws(ReadError) -> UIImage

        init(cover: @escaping () async throws(ReadError) -> UIImage) {
            self.cover = cover
        }

        let sourceURL: AbsoluteURL? = nil

        func estimatedLength() async throws(ReadError) -> UInt64? {
            nil
        }

        func properties() async throws(ReadError) -> ResourceProperties {
            ResourceProperties()
        }

        func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async throws(ReadError) {
            let image = try await cover()
            guard let data = image.pngData() else {
                throw ReadError.decoding("Failed to convert the cover bitmap to PNG data")
            }
            consume(data)
        }
    }
}
