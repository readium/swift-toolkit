//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

enum EPUBViewportAndLocationCalculatorTests {
    struct Viewport {
        @Test("builds resource list from a single-resource spread")
        func singleResourceReadingOrder() {
            let manifest = makeManifest(count: 2)
            let (_, viewport) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 0.5 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:]
            )
            #expect(viewport.resources.map(\.href) == [manifest.readingOrder[0].url()])
        }

        @Test("records progression range for the visible resource")
        func progressionRange() {
            let manifest = makeManifest(count: 2)
            let (_, viewport) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.25 ... 0.75 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:]
            )
            #expect(viewport.resources.first(where: { $0.href.string == manifest.readingOrder[0].href })?.progression == 0.25 ... 0.75)
        }

        @Test("includes both resources for a two-index spread")
        func twoIndexSpread() {
            let manifest = makeManifest(count: 2)
            let ro = manifest.readingOrder
            let (_, viewport) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 1,
                progression: { i in i == 0 ? 0.0 ... 1.0 : 0.0 ... 1.0 },
                manifest: manifest,
                readingOrder: ro,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 1),
                tableOfContentsTitleByHref: [:]
            )
            #expect(viewport.resources.map(\.href) == [ro[0].url(), ro[1].url()])
            #expect(viewport.resources.first(where: { $0.href.string == ro[0].href })?.progression == 0.0 ... 1.0)
            #expect(viewport.resources.first(where: { $0.href.string == ro[1].href })?.progression == 0.0 ... 1.0)
        }

        @Test("total progression range lower bound matches locator totalProgression")
        func totalProgressionLowerBoundMatchesLocator() {
            let manifest = makeManifest(count: 2)
            let (locator, viewport) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.5 ... 0.75 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:]
            )
            #expect(viewport.progression.lowerBound == locator?.locations.totalProgression)
        }
    }

    @Suite("Locator - positions available") struct LocatorWithPositions {
        // 2 resources × 4 positions = 8 total.
        // Resource 0: totalProgression 0/8 … 3/8; resource 1: 4/8 … 7/8.
        // resourceTotalProgressionEnd for resource 0 = 4/8 = 0.5.

        @Test("totalProgression at start of first resource is 0.0")
        func totalProgressionAtStart() {
            let manifest = makeManifest(count: 2)
            let (locator, _) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 0.0 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:]
            )
            #expect(locator?.locations.totalProgression == 0.0)
        }

        @Test("totalProgression at end of first resource equals start of second")
        func totalProgressionAtResourceBoundary() {
            let manifest = makeManifest(count: 2)
            let (locator, _) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 1.0 ... 1.0 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:]
            )
            // Resource 0 ends where resource 1 begins: totalProgression = 4/8 = 0.5
            #expect(locator?.locations.totalProgression == 0.5)
        }

        @Test("totalProgression at end of last resource is 1.0")
        func totalProgressionAtEnd() {
            let manifest = makeManifest(count: 2)
            let (locator, _) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 1 ... 1,
                progression: { _ in 1.0 ... 1.0 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:]
            )
            #expect(locator?.locations.totalProgression == 1.0)
        }

        @Test("totalProgression interpolates linearly mid-resource")
        func totalProgressionInterpolation() {
            // At 0.5 progression in resource 0:
            // totalProgression = 0.0 + 0.5 * (0.5 - 0.0) = 0.25
            let manifest = makeManifest(count: 2)
            let (locator, _) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.5 ... 0.5 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:]
            )
            #expect(locator?.locations.totalProgression == 0.25)
        }

        @Test("progression field reflects actual scroll offset")
        func progressionFieldIsScrollOffset() {
            let manifest = makeManifest(count: 2)
            let (locator, _) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.3 ... 0.7 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:]
            )
            #expect(locator?.locations.progression == 0.3)
        }

        @Test("position index is selected via ceil of resource progression")
        func positionIndexViaCeil() {
            // progression=0.5, 4 positions → ceil(0.5 * 3) = ceil(1.5) = 2 → position 3 (1-based)
            let manifest = makeManifest(count: 2)
            let (locator, _) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.5 ... 0.5 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:]
            )
            // Index 2 in resource 0 has position number 3 (absolute index 2, 1-based)
            #expect(locator?.locations.position == 3)
        }

        @Test("position index at start of resource is 0")
        func positionIndexAtStart() {
            // progression=0.0, 4 positions → ceil(0.0 * 3) = 0
            let manifest = makeManifest(count: 2)
            let (locator, _) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 0.0 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:]
            )
            // Index 0 in resource 0 has position number 1
            #expect(locator?.locations.position == 1)
        }

        @Test("title is taken from tableOfContentsTitleByHref")
        func titleFromTOC() {
            let manifest = makeManifest(count: 1)
            let (locator, _) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 0.0 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 1, positionsPerResource: 1),
                tableOfContentsTitleByHref: [manifest.readingOrder[0].url(): "Chapter One"]
            )
            #expect(locator?.title == "Chapter One")
        }

        @Test("title is nil when href not in table of contents")
        func noTitle() {
            let manifest = makeManifest(count: 1)
            let (locator, _) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 0.0 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 1, positionsPerResource: 1),
                tableOfContentsTitleByHref: [:]
            )
            #expect(locator?.title == nil)
        }
    }

    @Suite("Viewport positions - positions available") struct ViewportPositions {
        @Test("positions range is single position when viewing start of resource")
        func singlePositionAtStart() {
            let manifest = makeManifest(count: 2)
            let (_, viewport) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 0.0 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:]
            )
            // firstProgression=0.0 → positionIndex=0 → position 1
            // lastProgression=0.0 → ceil(0.0*3)-1 = -1 → max(0,-1) = 0 → position 1
            #expect(viewport.positions == 1 ... 1)
        }

        @Test("positions range spans multiple positions when viewport shows a range")
        func multiPositionRange() {
            // firstProgression=0.0 → firstPositionIndex=0 → position 1
            // lastProgression=1.0 → lastPositionIndex=count-1=3 → position 4
            let manifest = makeManifest(count: 2)
            let (_, viewport) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 1.0 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:]
            )
            #expect(viewport.positions == 1 ... 4)
        }

        @Test("lastProgression == 1.0 uses last position index in resource")
        func lastProgressionExactlyOne() {
            let manifest = makeManifest(count: 1)
            let positions = makePositions(resourceCount: 1, positionsPerResource: 4)
            let (_, viewport) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 1.0 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: positions,
                tableOfContentsTitleByHref: [:]
            )
            // lastPositionIndex = count - 1 = 3 → position 4
            #expect(viewport.positions?.upperBound == 4)
        }

        @Test("lastProgression near 1.0 does not reach last position index")
        func lastProgressionNearOne() {
            // The last position index is only reached when lastProgression is
            // exactly 1.0 (handled by the special-case branch). For any value
            // strictly below 1.0 the formula is ceil(x * (count-1)) - 1, which
            // advances one position at a time as x increases — intentionally
            // stopping one step short of the final position until the very end.
            // This prevents the position from jumping ahead before the reader
            // has fully scrolled into it.
            let manifest = makeManifest(count: 1)
            let positions = makePositions(resourceCount: 1, positionsPerResource: 4)
            let (_, viewport) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                // upperBound is just below 1.0 but not exactly 1.0
                progression: { _ in 0.0 ... 0.9999 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: positions,
                tableOfContentsTitleByHref: [:]
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
        func progressionAtStart() {
            let manifest = makeManifest(count: 2)
            let (_, viewport) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 0.5 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:]
            )
            // lower = 0.0 + 0.0 * 0.5 = 0.0
            // upper = 0.0 + 0.5 * 0.5 = 0.25
            #expect(viewport.progression.lowerBound == 0.0)
            #expect(viewport.progression.upperBound == 0.25)
        }

        @Test("progression upper bound is 1.0 when scrolled to end of last resource")
        func progressionAtEnd() {
            let manifest = makeManifest(count: 2)
            let (_, viewport) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 1 ... 1,
                progression: { _ in 0.5 ... 1.0 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4),
                tableOfContentsTitleByHref: [:]
            )
            // lower = 0.5 + 0.5 * 0.5 = 0.75
            // upper = 0.5 + 1.0 * 0.5 = 1.0
            #expect(viewport.progression.upperBound == 1.0)
        }

        @Test("progression spans both resources in a two-index FXL spread")
        func progressionSpansBothResources() {
            // Resource 0 visible fully, resource 1 visible fully.
            // lower = 0.0 (start of resource 0), upper = 1.0 (end of resource 1)
            let manifest = makeManifest(count: 2)
            let (_, viewport) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 1,
                progression: { _ in 0.0 ... 1.0 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 1),
                tableOfContentsTitleByHref: [:]
            )
            #expect(viewport.progression == 0.0 ... 1.0)
        }
    }

    @Suite("Locator - no positions (manifest fallback)") struct Fallback {
        @Test("builds the locator from the manifest when positionsByReadingOrder is empty")
        func useFallback() {
            let manifest = makeManifest(readingOrder: [
                Link(href: "chap1.html", mediaType: .html, title: "Fallback"),
            ])
            let (locator, _) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.3 ... 0.3 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: [],
                tableOfContentsTitleByHref: [:]
            )
            #expect(locator?.title == "Fallback")
        }

        @Test("progression is set on the fallback locator")
        func fallbackProgressionIsSet() {
            let manifest = makeManifest(count: 1)
            let (locator, _) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.42 ... 0.42 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: [],
                tableOfContentsTitleByHref: [:]
            )
            #expect(locator?.locations.progression == 0.42)
        }

        @Test("uses fallback when positions array does not cover the current resource index")
        func fallbackWhenPositionsMissingForResource() {
            let manifest = makeManifest(readingOrder: [
                Link(href: "chap1.html", mediaType: .html),
                Link(href: "chap2.html", mediaType: .html),
                Link(href: "chap3.html", mediaType: .html, title: "Chapter 3"),
            ])
            let (locator, _) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 2 ... 2,
                progression: { _ in 0.5 ... 0.5 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                // positions only cover resources 0 and 1, not resource 2
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 1),
                tableOfContentsTitleByHref: [:]
            )
            #expect(locator?.title == "Chapter 3")
            #expect(locator?.locations.progression == 0.5)
        }

        @Test("locator is nil when the link is not in the manifest")
        func unknownLink() {
            let manifest = makeManifest(count: 1)
            let (locator, _) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 1.0 },
                manifest: manifest,
                readingOrder: [Link(href: "not-in-manifest.html", mediaType: .html)],
                positionsByReadingOrder: [],
                tableOfContentsTitleByHref: [:]
            )
            #expect(locator == nil)
        }

        @Test("viewport.positions is nil when no positions available")
        func viewportPositionsIsNil() {
            let manifest = makeManifest(count: 1)
            let (_, viewport) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 0,
                progression: { _ in 0.0 ... 1.0 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: [],
                tableOfContentsTitleByHref: [:]
            )
            #expect(viewport.positions == nil)
        }
    }

    @Suite("Two-index spread (FXL)") struct TwoIndexSpread {
        @Test("totalProgression is computed from the first resource's range")
        func totalProgressionUsesFirstResource() {
            // FXL: progression always returns 0...1, so firstProgression=0.0.
            // Resource 0 range: 0/2 = 0.0 … 1/2 = 0.5.
            // totalProgression = 0.0 + 0.0 * (0.5 - 0.0) = 0.0
            let manifest = makeManifest(count: 2)
            let (locator, _) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 1,
                progression: { _ in 0.0 ... 1.0 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 1),
                tableOfContentsTitleByHref: [:]
            )
            #expect(locator?.locations.totalProgression == 0.0)
        }

        @Test("viewport.positions spans both resources in a two-index FXL spread")
        func viewportPositionsSpanBothResources() {
            // Each FXL resource has one position; resource 0 → position 1, resource 1 → position 2.
            let manifest = makeManifest(count: 2)
            let (_, viewport) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 1,
                progression: { _ in 0.0 ... 1.0 },
                manifest: manifest,
                readingOrder: manifest.readingOrder,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 1),
                tableOfContentsTitleByHref: [:]
            )
            #expect(viewport.positions == 1 ... 2)
        }

        @Test("viewport resources contains an entry for each visible resource")
        func viewportContainsBothResources() {
            let manifest = makeManifest(count: 2)
            let ro = manifest.readingOrder
            let (_, viewport) = EPUBViewportAndLocationCalculator.compute(
                readingOrderIndices: 0 ... 1,
                progression: { i in i == 0 ? 0.1 ... 0.9 : 0.2 ... 0.8 },
                manifest: manifest,
                readingOrder: ro,
                positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 1),
                tableOfContentsTitleByHref: [:]
            )
            #expect(viewport.resources.first(where: { $0.href.string == ro[0].href })?.progression == 0.1 ... 0.9)
            #expect(viewport.resources.first(where: { $0.href.string == ro[1].href })?.progression == 0.2 ... 0.8)
        }
    }
}

// MARK: - Helpers

/// Builds a manifest whose reading order contains `count` links with hrefs
/// "chap1.html", "chap2.html", …
private func makeManifest(count: Int) -> Manifest {
    makeManifest(readingOrder: (1 ... count).map { Link(href: "chap\($0).html", mediaType: .html) })
}

private func makeManifest(readingOrder: [Link]) -> Manifest {
    Manifest(metadata: Metadata(title: ""), readingOrder: readingOrder)
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
