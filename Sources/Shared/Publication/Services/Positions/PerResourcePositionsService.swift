//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Simple `PositionsService` for a `Publication` which generates one position per `readingOrder`
/// resource.
public final class PerResourcePositionsService: PositionsService, Sendable {
    private let positions: [[Locator]]

    init(readingOrder: [Link], fallbackMediaType: MediaType) {
        let pageCount = readingOrder.count
        positions = readingOrder.enumerated().map { index, link in
            [
                Locator(
                    href: link.url(),
                    mediaType: link.mediaType ?? fallbackMediaType,
                    title: link.title,
                    locations: Locator.Locations(
                        totalProgression: pageCount > 0 ? Double(index) / Double(pageCount) : 0.0,
                        position: index + 1
                    )
                ),
            ]
        }
    }

    public func positionsByReadingOrder() async -> ReadResult<[[Locator]]> {
        .success(positions)
    }

    public static func makeFactory(fallbackMediaType: MediaType) -> @Sendable (PublicationServiceContext) -> PerResourcePositionsService {
        { context in
            PerResourcePositionsService(readingOrder: context.manifest.readingOrder, fallbackMediaType: fallbackMediaType)
        }
    }
}
