//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Simple `PositionsService` for a `Publication` which generates one position per `readingOrder`
/// resource.
public final class PerResourcePositionsService: PositionsService, @unchecked Sendable {
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

    private let lock = NSLock()

    private var _pageCount: Int?
    private var pageCount: Int {
        lock.withLock {
            if let count = _pageCount { return count }
            let count = readingOrder.count
            _pageCount = count
            return count
        }
    }

    private var _positions: [[Locator]]?
    private var positions: [[Locator]] {
        lock.withLock {
            if let positions = _positions { return positions }
            
            // We capture pageCount outside the map if we want to be safe, but pageCount accessor is locked too.
            // Recursive lock would be needed if we call pageCount inside. NSLock is not recursive.
            // Let's compute count locally.
            let count = readingOrder.count
            _pageCount = count // Update cache while we are here
            
            let positions: [[Locator]] = readingOrder.enumerated().map { index, link in
                [
                    Locator(
                        href: link.url(),
                        mediaType: link.mediaType ?? fallbackMediaType,
                        title: link.title,
                        locations: Locator.Locations(
                            totalProgression: Double(index) / Double(count),
                            position: index + 1
                        )
                    ),
                ]
            }
            _positions = positions
            return positions
        }
    }

    public static func makeFactory(fallbackMediaType: MediaType) -> PositionsServiceFactory {
        { context in
            PerResourcePositionsService(readingOrder: context.manifest.readingOrder, fallbackMediaType: fallbackMediaType)
        }
    }
}
