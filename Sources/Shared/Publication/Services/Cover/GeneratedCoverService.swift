//
//  Copyright 2024 Readium Foundation. All rights reserved.
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

    private let makeCover: () throws -> UIImage
    private lazy var generatedCover = ResourceResult<UIImage> { try makeCover() }

    public init(makeCover: @escaping () throws -> UIImage) {
        self.makeCover = makeCover
    }

    public convenience init(cover: UIImage) {
        self.init(makeCover: { cover })
    }

    private let coverLink = Link(
        href: "/~readium/cover",
        type: "image/png",
        rel: .cover
    )

    public var cover: UIImage? { try? generatedCover.get() }

    public var links: [Link] { [coverLink] }

    public func get(link: Link) -> Resource? {
        guard link.href == coverLink.href else {
            return nil
        }

        return LazyResource {
            do {
                let cover = try self.generatedCover.get()
                return try DataResource(
                    link: self.coverLink.copy(
                        height: Int(cover.size.height),
                        width: Int(cover.size.width)
                    ),
                    data: cover.pngData().orThrow(Error.generationFailed)
                )
            } catch {
                return FailureResource(link: self.coverLink, error: .wrap(error))
            }
        }
    }

    public static func makeFactory(makeCover: @escaping () -> UIImage) -> (PublicationServiceContext) -> GeneratedCoverService? {
        { _ in GeneratedCoverService(makeCover: makeCover) }
    }

    public static func makeFactory(cover: UIImage) -> (PublicationServiceContext) -> GeneratedCoverService? {
        { _ in GeneratedCoverService(cover: cover) }
    }
}
