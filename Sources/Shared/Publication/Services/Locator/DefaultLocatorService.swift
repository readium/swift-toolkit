//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A default implementation of the `LocatorService` using the `PositionsService` to locate its inputs.
open class DefaultLocatorService: LocatorService, Loggable {
    public let publication: Weak<Publication>

    public init(publication: Weak<Publication>) {
        self.publication = publication
    }

    /// Locates the target of the given `locator`.
    ///
    /// If `locator.href` can be found in the links, `locator` will be returned directly.
    /// Otherwise, will attempt to find the closest match using `totalProgression`, `position`,
    /// `fragments`, etc.
    open func locate(_ locator: Locator) async -> Locator? {
        guard let publication = publication() else {
            return nil
        }

        if publication.linkWithHREF(locator.href) != nil {
            return locator
        }

        if
            let totalProgression = locator.locations.totalProgression,
            let target = await locate(progression: totalProgression)
        {
            return target.copy(
                title: locator.title,
                text: { $0 = locator.text }
            )
        }

        return nil
    }

    open func locate(_ link: Link) async -> Locator? {
        let originalHREF = link.url()
        let fragment = originalHREF.fragment
        let href = originalHREF.removingFragment()

        guard
            let resourceLink = publication()?.linkWithHREF(href),
            let type = resourceLink.mediaType
        else {
            return nil
        }

        return Locator(
            href: href,
            mediaType: type,
            title: resourceLink.title ?? link.title,
            locations: Locator.Locations(
                fragments: Array(ofNotNil: fragment),
                progression: (fragment == nil) ? 0.0 : nil
            )
        )
    }

    open func locate(progression totalProgression: Double) async -> Locator? {
        guard 0.0 ... 1.0 ~= totalProgression else {
            log(.error, "Progression must be between 0.0 and 1.0, received \(totalProgression)")
            return nil
        }

        guard
            let positions = await publication()?.positionsByReadingOrder().getOrNil(),
            let (readingOrderIndex, position) = findClosest(to: totalProgression, in: positions)
        else {
            return nil
        }

        return position.copy(locations: {
            $0.totalProgression = totalProgression

            if let progression = self.resourceProgression(for: totalProgression, in: positions, readingOrderIndex: readingOrderIndex) {
                $0.progression = progression
            }
        })
    }

    /// Computes the progression relative to a reading order resource at the given index, from its `totalProgression`
    /// relative to the whole publication.
    private func resourceProgression(for totalProgression: Double, in positions: [[Locator]], readingOrderIndex: Int) -> Double? {
        guard let startProgression = positions[readingOrderIndex].first?.locations.totalProgression else {
            return nil
        }
        let endProgression = positions.getOrNil(readingOrderIndex + 1)?.first?.locations.totalProgression ?? 1.0

        if totalProgression <= startProgression {
            return 0.0
        } else if totalProgression >= endProgression {
            return 1.0
        } else {
            return (totalProgression - startProgression) / (endProgression - startProgression)
        }
    }

    /// Finds the [Locator] in the given `positions` which is the closest to the given `totalProgression`, without
    /// exceeding it.
    private func findClosest(to totalProgression: Double, in positions: [[Locator]]) -> (readingOrderIndex: Int, position: Locator)? {
        guard let lastPosition = findLast(in: positions) else {
            return nil
        }

        if let lastProgression = lastPosition.item.locations.totalProgression, totalProgression >= lastProgression {
            return (readingOrderIndex: lastPosition.index.x, position: lastPosition.item)
        }

        func inBetween(_ first: Locator, _ second: Locator) -> Bool {
            if
                let prog1 = first.locations.totalProgression,
                let prog2 = second.locations.totalProgression,
                prog1 ..< prog2 ~= totalProgression
            {
                return true
            }
            return false
        }

        guard let position = findFirstByPair(in: positions, where: inBetween) else {
            return nil
        }
        return (readingOrderIndex: position.index.x, position: position.item)
    }

    /// Holds an item and its position in a two-dimensional array.
    private typealias Match<T> = (index: (x: Int, y: Int), item: T)

    /// Finds the first item matching the given condition when paired with its successor.
    private func findFirstByPair<T>(in items: [[T]], where condition: (T, T) -> Bool) -> Match<T>? {
        var previous: Match<T>? = nil

        for (x, section) in items.enumerated() {
            for (y, item) in section.enumerated() {
                if let previous = previous, condition(previous.item, item) {
                    return previous
                }
                previous = ((x, y), item)
            }
        }

        return nil
    }

    /// Finds the last item in the last non-empty list of `items`.
    private func findLast<T>(in items: [[T]]) -> Match<T>? {
        var last: Match<T>? = nil

        for (x, section) in items.enumerated() {
            for (y, item) in section.enumerated() {
                last = ((x, y), item)
            }
        }
        return last
    }
}
