//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

@Suite enum EPUBViewportAndLocationCalculatorTests {
    @Suite struct Viewport {
        @Test("builds resource list from a single-resource spread")
        func singleResourceReadingOrder() async {
            let ro = makeReadingOrder(count: 2)
            let (_, viewport) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 0.5 },
                readingOrder: ro,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            #expect(viewport.resources.map(\.href) == [ro[0].url()])
        }

        @Test("records progression range for the visible resource")
        func progressionRange() async {
            let ro = makeReadingOrder(count: 2)
            let (_, viewport) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.25 ... 0.75 },
                readingOrder: ro,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            #expect(viewport.resources.first(where: { $0.href.string == ro[0].href })?.progression == 0.25 ... 0.75)
        }

        @Test("includes both resources for a two-index spread")
        func twoIndexSpread() async {
            let ro = makeReadingOrder(count: 2)
            let (_, viewport) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 1,
                progression: { i in i == 0 ? 0.0 ... 1.0 : 0.0 ... 1.0 },
                readingOrder: ro,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 1),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            #expect(viewport.resources.map(\.href) == [ro[0].url(), ro[1].url()])
            #expect(viewport.resources.first(where: { $0.href.string == ro[0].href })?.progression == 0.0 ... 1.0)
            #expect(viewport.resources.first(where: { $0.href.string == ro[1].href })?.progression == 0.0 ... 1.0)
        }

        @Test("total progression range lower bound matches locator totalProgression")
        func totalProgressionLowerBoundMatchesLocator() async {
            let (locator, viewport) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.5 ... 0.75 },
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            #expect(viewport.progression.lowerBound == locator?.locations.totalProgression)
        }
    }

    @Suite("Locator - positions available") struct LocatorWithPositions {
        // 2 resources × 4 positions = 8 total.
        // Resource 0: totalProgression 0/8 … 3/8; resource 1: 4/8 … 7/8.
        // resourceTotalProgressionEnd for resource 0 = 4/8 = 0.5.

        @Test("totalProgression at start of first resource is 0.0")
        func totalProgressionAtStart() async {
            let (locator, _) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 0.0 },
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            #expect(locator?.locations.totalProgression == 0.0)
        }

        @Test("totalProgression at end of first resource equals start of second")
        func totalProgressionAtResourceBoundary() async {
            let (locator, _) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 1.0 ... 1.0 },
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            // Resource 0 ends where resource 1 begins: totalProgression = 4/8 = 0.5
            #expect(locator?.locations.totalProgression == 0.5)
        }

        @Test("totalProgression at end of last resource is 1.0")
        func totalProgressionAtEnd() async {
            let (locator, _) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 1 ... 1,
                progression: { _ in 1.0 ... 1.0 },
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            #expect(locator?.locations.totalProgression == 1.0)
        }

        @Test("totalProgression interpolates linearly mid-resource")
        func totalProgressionInterpolation() async {
            // At 0.5 progression in resource 0:
            // totalProgression = 0.0 + 0.5 * (0.5 - 0.0) = 0.25
            let (locator, _) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.5 ... 0.5 },
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            #expect(locator?.locations.totalProgression == 0.25)
        }

        @Test("progression field reflects actual scroll offset")
        func progressionFieldIsScrollOffset() async {
            let (locator, _) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.3 ... 0.7 },
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            #expect(locator?.locations.progression == 0.3)
        }

        @Test("position index is selected via ceil of resource progression")
        func positionIndexViaCeil() async {
            // progression=0.5, 4 positions → ceil(0.5 * 3) = ceil(1.5) = 2 → position 3 (1-based)
            let (locator, _) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.5 ... 0.5 },
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            // Index 2 in resource 0 has position number 3 (absolute index 2, 1-based)
            #expect(locator?.locations.position == 3)
        }

        @Test("position index at start of resource is 0")
        func positionIndexAtStart() async {
            // progression=0.0, 4 positions → ceil(0.0 * 3) = 0
            let (locator, _) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 0.0 },
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            // Index 0 in resource 0 has position number 1
            #expect(locator?.locations.position == 1)
        }

        @Test("title is taken from tableOfContentsTitleByHref")
        func titleFromTOC() async {
            let ro = makeReadingOrder(count: 1)
            let (locator, _) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 0.0 },
                readingOrder: ro,
                positionsByReadingOrder: makePositions(resourceCount: 1, positionsPerResource: 1),
                tableOfContentsTitleByHref: [ro[0].url(): "Chapter One"],
                fallbackLocator: noFallback
            )
            #expect(locator?.title == "Chapter One")
        }

        @Test("title is nil when href not in table of contents")
        func noTitle() async {
            let (locator, _) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 0.0 },
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: makePositions(resourceCount: 1, positionsPerResource: 1),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            #expect(locator?.title == nil)
        }
    }

    @Suite("Viewport positions - positions available") struct ViewportPositions {
        @Test("positions range is single position when viewing start of resource")
        func singlePositionAtStart() async {
            let (_, viewport) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 0.0 },
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            // firstProgression=0.0 → positionIndex=0 → position 1
            // lastProgression=0.0 → ceil(0.0*3)-1 = -1 → max(0,-1) = 0 → position 1
            #expect(viewport.positions == 1 ... 1)
        }

        @Test("positions range spans multiple positions when viewport shows a range")
        func multiPositionRange() async {
            // firstProgression=0.0 → firstPositionIndex=0 → position 1
            // lastProgression=1.0 → lastPositionIndex=count-1=3 → position 4
            let (_, viewport) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 1.0 },
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            #expect(viewport.positions == 1 ... 4)
        }

        @Test("lastProgression == 1.0 uses last position index in resource")
        func lastProgressionExactlyOne() async {
            let positions = makePositions(resourceCount: 1, positionsPerResource: 4)
            let (_, viewport) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 1.0 },
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: positions,
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            // lastPositionIndex = count - 1 = 3 → position 4
            #expect(viewport.positions?.upperBound == 4)
        }

        @Test("lastProgression near 1.0 does not reach last position index")
        func lastProgressionNearOne() async {
            // The last position index is only reached when lastProgression is
            // exactly 1.0 (handled by the special-case branch). For any value
            // strictly below 1.0 the formula is ceil(x * (count-1)) - 1, which
            // advances one position at a time as x increases — intentionally
            // stopping one step short of the final position until the very end.
            // This prevents the position from jumping ahead before the reader
            // has fully scrolled into it.
            let positions = makePositions(resourceCount: 1, positionsPerResource: 4)
            let (_, viewport) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                // upperBound is just below 1.0 but not exactly 1.0
                progression: { _ in 0.0 ... 0.9999 },
                readingOrder: makeReadingOrder(count: 1),
                positionsByReadingOrder: positions,
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            // ceil(0.9999 * 3) - 1 = ceil(2.9997) - 1 = 3 - 1 = 2 → position 3
            #expect(viewport.positions?.upperBound == 3)
        }
    }

    @Suite("Viewport progression - positions available") struct ViewportProgression {
        // 2 resources × 4 positions = 8 total.
        // Resource 0 total progression window: 0.0 … 0.5
        // Resource 1 total progression window: 0.5 … 1.0

        @Test("progression lower bound is 0.0 when scrolled to start")
        func progressionAtStart() async {
            let (_, viewport) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 0.5 },
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            // lower = 0.0 + 0.0 * 0.5 = 0.0
            // upper = 0.0 + 0.5 * 0.5 = 0.25
            #expect(viewport.progression.lowerBound == 0.0)
            #expect(viewport.progression.upperBound == 0.25)
        }

        @Test("progression upper bound is 1.0 when scrolled to end of last resource")
        func progressionAtEnd() async {
            let (_, viewport) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 1 ... 1,
                progression: { _ in 0.5 ... 1.0 },
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            // lower = 0.5 + 0.5 * 0.5 = 0.75
            // upper = 0.5 + 1.0 * 0.5 = 1.0
            #expect(viewport.progression.upperBound == 1.0)
        }

        @Test("progression spans both resources in a two-index FXL spread")
        func progressionSpansBothResources() async {
            // Resource 0 visible fully, resource 1 visible fully.
            // lower = 0.0 (start of resource 0), upper = 1.0 (end of resource 1)
            let (_, viewport) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 1,
                progression: { _ in 0.0 ... 1.0 },
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 1),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            #expect(viewport.progression == 0.0 ... 1.0)
        }
    }

    @Suite("Locator - no positions (fallback)") struct Fallback {
        @Test("uses fallback locator when positionsByReadingOrder is empty")
        func useFallback() async {
            let ro = makeReadingOrder(count: 1)
            let fallback = Locator(href: ro[0].url(), mediaType: .html, title: "Fallback")
            let (locator, _) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.3 ... 0.3 },
                readingOrder: ro,
                positionsByReadingOrder: [],
                tableOfContentsTitleByHref: [:],
                fallbackLocator: { _ in fallback }
            )
            #expect(locator?.title == "Fallback")
        }

        @Test("progression is set on the fallback locator")
        func fallbackProgressionIsSet() async {
            let ro = makeReadingOrder(count: 1)
            let fallback = Locator(href: ro[0].url(), mediaType: .html)
            let (locator, _) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.42 ... 0.42 },
                readingOrder: ro,
                positionsByReadingOrder: [],
                tableOfContentsTitleByHref: [:],
                fallbackLocator: { _ in fallback }
            )
            #expect(locator?.locations.progression == 0.42)
        }

        @Test("uses fallback when positions array does not cover the current resource index")
        func fallbackWhenPositionsMissingForResource() async {
            let ro = makeReadingOrder(count: 3)
            let fallback = Locator(href: ro[2].url(), mediaType: .html, title: "Chapter 3")
            let (locator, _) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 2 ... 2,
                progression: { _ in 0.5 ... 0.5 },
                readingOrder: ro,
                // positions only cover resources 0 and 1, not resource 2
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 1),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: { _ in fallback }
            )
            #expect(locator?.title == "Chapter 3")
            #expect(locator?.locations.progression == 0.5)
        }

        @Test("viewport.positions is nil when no positions available")
        func viewportPositionsIsNil() async {
            let ro = makeReadingOrder(count: 1)
            let (_, viewport) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 1.0 },
                readingOrder: ro,
                positionsByReadingOrder: [],
                tableOfContentsTitleByHref: [:],
                fallbackLocator: { link in Locator(href: link.url(), mediaType: .html) }
            )
            #expect(viewport.positions == nil)
        }
    }

    @Suite("Two-index spread (FXL)") struct TwoIndexSpread {
        @Test("totalProgression is computed from the first resource's range")
        func totalProgressionUsesFirstResource() async {
            // FXL: progression always returns 0...1, so firstProgression=0.0.
            // Resource 0 range: 0/2 = 0.0 … 1/2 = 0.5.
            // totalProgression = 0.0 + 0.0 * (0.5 - 0.0) = 0.0
            let (locator, _) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 1,
                progression: { _ in 0.0 ... 1.0 },
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 1),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            #expect(locator?.locations.totalProgression == 0.0)
        }

        @Test("viewport.positions spans both resources in a two-index FXL spread")
        func viewportPositionsSpanBothResources() async {
            // Each FXL resource has one position; resource 0 → position 1, resource 1 → position 2.
            let (_, viewport) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 1,
                progression: { _ in 0.0 ... 1.0 },
                readingOrder: makeReadingOrder(count: 2),
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 1),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            #expect(viewport.positions == 1 ... 2)
        }

        @Test("viewport resources contains an entry for each visible resource")
        func viewportContainsBothResources() async {
            let ro = makeReadingOrder(count: 2)
            let (_, viewport) = await EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 1,
                progression: { i in i == 0 ? 0.1 ... 0.9 : 0.2 ... 0.8 },
                readingOrder: ro,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 1),
                tableOfContentsTitleByHref: [:],
                fallbackLocator: noFallback
            )
            #expect(viewport.resources.first(where: { $0.href.string == ro[0].href })?.progression == 0.1 ... 0.9)
            #expect(viewport.resources.first(where: { $0.href.string == ro[1].href })?.progression == 0.2 ... 0.8)
        }
    }
}

// MARK: - Helpers

/// Builds a reading order of `count` links with hrefs "chap1.html", "chap2.html", …
private func makeReadingOrder(count: Int) -> [Link] {
    (1 ... count).map { Link(href: "chap\($0).html", mediaType: .html) }
}

/// Builds positions for `resourceCount` resources, each with `positionsPerResource`
/// positions. `totalProgression` is distributed evenly across the whole publication;
/// `progression` within each resource is distributed evenly; position numbers are
/// 1-based and sequential.
private func makePositions(resourceCount: Int, positionsPerResource: Int) -> [[Locator]] {
    let total = resourceCount * positionsPerResource

    return (0 ..< resourceCount).map { r in
        (0 ..< positionsPerResource).map { p in
            let absoluteIndex = r * positionsPerResource + p
            return Locator(
                href: AnyURL(string: "chap\(r + 1).html")!,
                mediaType: .html,
                locations: .init(
                    progression: positionsPerResource > 1
                        ? Double(p) / Double(positionsPerResource - 1)
                        : 0.0,
                    totalProgression: Double(absoluteIndex) / Double(total),
                    position: absoluteIndex + 1
                )
            )
        }
    }
}

/// A no-op fallback locator used when positions are available (fallback branch
/// should not be reached).
private func noFallback(_ link: Link) async -> Locator? {
    nil
}
