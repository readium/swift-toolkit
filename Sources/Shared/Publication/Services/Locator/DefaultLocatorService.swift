//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A default implementation of the `LocatorService` using the `PositionsService` to locate its inputs.
open class DefaultLocatorService: LocatorService, Loggable {
    
    let readingOrder: [Link]
    let positionsByReadingOrder: () -> [[Locator]]
    
    public init(readingOrder: [Link], positionsByReadingOrder: @escaping () -> [[Locator]]) {
        self.readingOrder = readingOrder
        self.positionsByReadingOrder = positionsByReadingOrder
    }

    public convenience init(readingOrder: [Link], publication: Weak<Publication>) {
        self.init(readingOrder: readingOrder, positionsByReadingOrder: { publication()?.positionsByReadingOrder ?? [] })
    }

    open func locate(_ locator: Locator) -> Locator? {
        guard readingOrder.firstIndex(withHREF: locator.href) != nil else {
            return nil
        }
        
        return locator
    }
    
    open func locate(progression totalProgression: Double) -> Locator? {
        guard 0.0...1.0 ~= totalProgression else {
            log(.error, "Progression must be between 0.0 and 1.0, received \(totalProgression)")
            return nil
        }

        let positions = positionsByReadingOrder()
        guard let (readingOrderIndex, position) = findClosest(to: totalProgression, in: positions) else {
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
                prog1..<prog2 ~= totalProgression
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
