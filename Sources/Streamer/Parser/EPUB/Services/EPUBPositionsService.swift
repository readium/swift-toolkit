//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Positions Service for an EPUB from its `readingOrder` and `fetcher`.
///
/// The `presentation` is used to apply different calculation strategy if the resource has a
/// reflowable or fixed layout.
///
/// https://github.com/readium/architecture/blob/master/models/locators/best-practices/format.md#epub
/// https://github.com/readium/architecture/issues/101
///
public actor EPUBPositionsService: PositionsService {
    public static func makeFactory(reflowableStrategy: ReflowableStrategy = .recommended) -> (PublicationServiceContext) -> EPUBPositionsService? {
        { context in
            EPUBPositionsService(
                readingOrder: context.manifest.readingOrder,
                layout: context.manifest.metadata.layout,
                container: context.container,
                reflowableStrategy: reflowableStrategy
            )
        }
    }

    /// Strategy used to calculate the number of positions in a reflowable resource.
    ///
    /// Note that a fixed-layout resource always has a single position.
    public enum ReflowableStrategy {
        /// Use the archive entry length (whether it is compressed or stored) and split it by the given `pageLength`.
        case archiveEntryLength(pageLength: Int)

        /// Recommended historical strategy: archive entry length split by 1024 bytes pages.
        ///
        /// This strategy is used by Adobe RMSDK as well.
        /// See https://github.com/readium/architecture/issues/123
        public static var recommended = archiveEntryLength(pageLength: 1024)

        /// Returns the number of positions in the given `resource` according to the strategy.
        func positionCount(for link: Link, resource: Resource) async -> Int {
            switch self {
            case let .archiveEntryLength(pageLength):
                let length = await {
                    if let l = try? await resource.properties().map({ $0.archive?.entryLength }).get() {
                        return l
                    } else if let l = try? await resource.estimatedLength().get() {
                        return l
                    } else {
                        return 0
                    }
                }()
                return max(1, Int(ceil(Double(length) / Double(pageLength))))
            }
        }
    }

    private let readingOrder: [Link]
    private let layout: Layout?
    private let container: Container
    private let reflowableStrategy: ReflowableStrategy

    init(
        readingOrder: [Link],
        layout: Layout?,
        container: Container,
        reflowableStrategy: ReflowableStrategy
    ) {
        self.readingOrder = readingOrder
        self.layout = layout
        self.container = container
        self.reflowableStrategy = reflowableStrategy
    }

    private var _positionsByReadingOrder: ReadResult<[[Locator]]>?

    public func positionsByReadingOrder() async -> ReadResult<[[Locator]]> {
        if _positionsByReadingOrder == nil {
            _positionsByReadingOrder = await .success(computePositionsByReadingOrder())
        }
        return _positionsByReadingOrder!
    }

    private func computePositionsByReadingOrder() async -> [[Locator]] {
        var lastPositionOfPreviousResource = 0
        var positions = await readingOrder.asyncMap { link -> [Locator] in
            let (lastPosition, positions): (Int, [Locator]) = await {
                switch layout {
                case .fixed:
                    return makePositions(ofFixedResource: link, from: lastPositionOfPreviousResource)
                case nil, .reflowable, .scrolled:
                    return await makePositions(ofReflowableResource: link, from: lastPositionOfPreviousResource)
                }
            }()
            lastPositionOfPreviousResource = lastPosition
            return positions
        }

        // Calculates totalProgression
        let totalPageCount = await positions.asyncMap(\.count).reduce(0, +)
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
    }

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

    private func makePositions(ofReflowableResource link: Link, from startPosition: Int) async -> (Int, [Locator]) {
        guard let resource = container[link.url()] else {
            return (startPosition, [])
        }
        let positionCount = await reflowableStrategy.positionCount(for: link, resource: resource)

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
            href: link.url(),
            mediaType: link.mediaType ?? .html,
            title: link.title,
            locations: .init(
                progression: progression,
                position: position
            )
        )
    }
}
