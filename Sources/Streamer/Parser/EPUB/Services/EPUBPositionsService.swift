//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Positions Service for an EPUB from its `readingOrder` and `fetcher`.
///
/// The `presentation` is used to apply different calculation strategy if the resource has a
/// reflowable or fixed layout.
///
/// https://github.com/readium/architecture/blob/master/models/locators/best-practices/format.md#epub
/// https://github.com/readium/architecture/issues/101
///
public final class EPUBPositionsService: PositionsService {
    public static func makeFactory(reflowableStrategy: ReflowableStrategy = .recommended) -> (PublicationServiceContext) -> EPUBPositionsService? {
        { context in
            EPUBPositionsService(
                readingOrder: context.manifest.readingOrder,
                presentation: context.manifest.metadata.presentation,
                fetcher: context.fetcher,
                reflowableStrategy: reflowableStrategy
            )
        }
    }

    /// Strategy used to calculate the number of positions in a reflowable resource.
    ///
    /// Note that a fixed-layout resource always has a single position.
    public enum ReflowableStrategy {
        /// Use the original length of each resource (before compression and encryption) and split it by the given
        /// `pageLength`.
        case originalLength(pageLength: Int)

        /// Use the archive entry length (whether it is compressed or stored) and split it by the given `pageLength`.
        case archiveEntryLength(pageLength: Int)

        /// Recommended historical strategy: archive entry length split by 1024 bytes pages.
        ///
        /// This strategy is used by Adobe RMSDK as well.
        /// See https://github.com/readium/architecture/issues/123
        public static var recommended = archiveEntryLength(pageLength: 1024)

        /// Returns the number of positions in the given `resource` according to the strategy.
        func positionCount(for resource: Resource) -> Int {
            switch self {
            case let .originalLength(pageLength):
                let length = resource.link.properties.encryption?.originalLength.map { UInt64($0) }
                    ?? (try? resource.length.get())
                    ?? 0
                return max(1, Int(ceil(Double(length) / Double(pageLength))))

            case let .archiveEntryLength(pageLength):
                let length = resource.link.properties.archive?.entryLength
                    ?? (try? resource.length.get())
                    ?? 0
                return max(1, Int(ceil(Double(length) / Double(pageLength))))
            }
        }
    }

    private let readingOrder: [Link]
    private let presentation: Presentation
    private let fetcher: Fetcher
    private let reflowableStrategy: ReflowableStrategy

    init(readingOrder: [Link], presentation: Presentation, fetcher: Fetcher, reflowableStrategy: ReflowableStrategy) {
        self.readingOrder = readingOrder
        self.fetcher = fetcher
        self.presentation = presentation
        self.reflowableStrategy = reflowableStrategy
    }

    public lazy var positionsByReadingOrder: [[Locator]] = {
        var lastPositionOfPreviousResource = 0
        var positions = readingOrder.map { link -> [Locator] in
            let (lastPosition, positions): (Int, [Locator]) = {
                if presentation.layout(of: link) == .fixed {
                    return makePositions(ofFixedResource: link, from: lastPositionOfPreviousResource)
                } else {
                    return makePositions(ofReflowableResource: link, from: lastPositionOfPreviousResource)
                }
            }()
            lastPositionOfPreviousResource = lastPosition
            return positions
        }

        // Calculates totalProgression
        let totalPageCount = positions.map(\.count).reduce(0, +)
        if totalPageCount > 0 {
            positions = positions.map { locators in
                locators.map { locator in
                    locator.copy(locations: {
                        if let position = $0.position {
                            $0.totalProgression = Double(position - 1) / Double(totalPageCount)
                        }
                    })
                }
            }
        }

        return positions
    }()

    private func makePositions(ofFixedResource link: Link, from startPosition: Int) -> (Int, [Locator]) {
        let position = startPosition + 1
        let positions = [
            makeLocator(
                for: link,
                progression: 0,
                position: position
            ),
        ]
        return (position, positions)
    }

    private func makePositions(ofReflowableResource link: Link, from startPosition: Int) -> (Int, [Locator]) {
        let resource = fetcher.get(link)
        let positionCount = reflowableStrategy.positionCount(for: resource)
        resource.close()

        let positions = (1 ... positionCount).map { position in
            makeLocator(
                for: link,
                progression: Double(position - 1) / Double(positionCount),
                position: startPosition + position
            )
        }
        return (startPosition + positionCount, positions)
    }

    private func makeLocator(for link: Link, progression: Double, position: Int) -> Locator {
        Locator(
            href: link.href,
            type: link.type ?? MediaType.html.string,
            title: link.title,
            locations: .init(
                progression: progression,
                position: position
            )
        )
    }
}
