//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Simple `PositionsService` for a `Publication` which generates one position per `readingOrder`
/// resource.
public final class PerResourcePositionsService: PositionsService {
    private let readingOrder: [Link]

    /// Media type that will be used as a fallback if the `Link` doesn't specify any.
    private let fallbackMediaType: MediaType

    init(readingOrder: [Link], fallbackMediaType: MediaType) {
        self.readingOrder = readingOrder
        self.fallbackMediaType = fallbackMediaType
    }

    public func positionsByReadingOrder() async -> ReadResult<[[Locator]]> {
        .success(positions)
    }

    private lazy var pageCount: Int = readingOrder.count

    private lazy var positions: [[Locator]] = readingOrder.enumerated().map { index, link in
        [
            Locator(
                href: link.url(),
                mediaType: link.mediaType ?? fallbackMediaType,
                title: link.title,
                locations: Locator.Locations(
                    totalProgression: Double(index) / Double(pageCount),
                    position: index + 1
                )
            ),
        ]
    }

    public static func makeFactory(fallbackMediaType: MediaType) -> (PublicationServiceContext) -> PerResourcePositionsService {
        { context in
            PerResourcePositionsService(readingOrder: context.manifest.readingOrder, fallbackMediaType: fallbackMediaType)
        }
    }
}
