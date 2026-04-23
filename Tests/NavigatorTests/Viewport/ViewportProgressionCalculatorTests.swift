//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

@Suite("ViewportProgressionCalculator") struct ViewportProgressionCalculatorTests {
    // Layout used by most tests:
    // 2 resources × 4 positions = 8 total.
    // Resource 0 total progression window: 0.0 … 0.5
    // Resource 1 total progression window: 0.5 … 1.0

    @Test("single resource, partial scroll — interpolates within window")
    func singleResourcePartialScroll() {
        // Resource 0, 50% through → totalProgression = 0.0 + 0.5 * 0.5 = 0.25
        let result = ViewportProgressionCalculator.totalProgressionRange(
            firstResource: (href: url("chap1.html"), progression: 0.5 ... 0.5),
            lastResource: (href: url("chap1.html"), progression: 0.5 ... 0.5),
            readingOrder: makeReadingOrder(count: 2),
            positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4)
        )
        #expect(result == 0.25 ... 0.25)
    }

    @Test("single resource, range — lower and upper interpolated independently")
    func singleResourceRange() {
        // lower: resource 0 at 0.0 → 0.0 + 0.0 * 0.5 = 0.0
        // upper: resource 0 at 0.5 → 0.0 + 0.5 * 0.5 = 0.25
        let result = ViewportProgressionCalculator.totalProgressionRange(
            firstResource: (href: url("chap1.html"), progression: 0.0 ... 0.5),
            lastResource: (href: url("chap1.html"), progression: 0.0 ... 0.5),
            readingOrder: makeReadingOrder(count: 2),
            positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4)
        )
        #expect(result == 0.0 ... 0.25)
    }

    @Test("two-resource spread — range spans both resource windows")
    func twoResourceSpread() {
        // lower: resource 0 at 0.0 → 0.0
        // upper: resource 1 at 1.0 → 0.5 + 1.0 * 0.5 = 1.0
        let result = ViewportProgressionCalculator.totalProgressionRange(
            firstResource: (href: url("chap1.html"), progression: 0.0 ... 1.0),
            lastResource: (href: url("chap2.html"), progression: 0.0 ... 1.0),
            readingOrder: makeReadingOrder(count: 2),
            positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4)
        )
        #expect(result == 0.0 ... 1.0)
    }

    @Test("last resource uses 1.0 as window end")
    func lastResourceUsesOneAsWindowEnd() {
        // Single resource publication — window is 0.0 … 1.0.
        // At 75% → 0.0 + 0.75 * 1.0 = 0.75
        let result = ViewportProgressionCalculator.totalProgressionRange(
            firstResource: (href: url("chap1.html"), progression: 0.75 ... 0.75),
            lastResource: (href: url("chap1.html"), progression: 0.75 ... 0.75),
            readingOrder: makeReadingOrder(count: 1),
            positionsByReadingOrder: makePositions(resourceCount: 1, positionsPerResource: 4)
        )
        #expect(result == 0.75 ... 0.75)
    }

    @Test("start of publication is 0.0")
    func startOfPublication() {
        let result = ViewportProgressionCalculator.totalProgressionRange(
            firstResource: (href: url("chap1.html"), progression: 0.0 ... 0.0),
            lastResource: (href: url("chap1.html"), progression: 0.0 ... 0.0),
            readingOrder: makeReadingOrder(count: 2),
            positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4)
        )
        #expect(result == 0.0 ... 0.0)
    }

    @Test("end of publication is 1.0")
    func endOfPublication() {
        let result = ViewportProgressionCalculator.totalProgressionRange(
            firstResource: (href: url("chap2.html"), progression: 1.0 ... 1.0),
            lastResource: (href: url("chap2.html"), progression: 1.0 ... 1.0),
            readingOrder: makeReadingOrder(count: 2),
            positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4)
        )
        #expect(result == 1.0 ... 1.0)
    }

    @Test("returns nil when positions are empty")
    func noPositionsReturnsNil() {
        let result = ViewportProgressionCalculator.totalProgressionRange(
            firstResource: (href: url("chap1.html"), progression: 0.5 ... 0.5),
            lastResource: (href: url("chap1.html"), progression: 0.5 ... 0.5),
            readingOrder: makeReadingOrder(count: 2),
            positionsByReadingOrder: []
        )
        #expect(result == nil)
    }

    @Test("returns nil when href not found in reading order")
    func unknownHrefReturnsNil() {
        let result = ViewportProgressionCalculator.totalProgressionRange(
            firstResource: (href: url("unknown.html"), progression: 0.5 ... 0.5),
            lastResource: (href: url("unknown.html"), progression: 0.5 ... 0.5),
            readingOrder: makeReadingOrder(count: 2),
            positionsByReadingOrder: makePositions(resourceCount: 2, positionsPerResource: 4)
        )
        #expect(result == nil)
    }
}

// MARK: - Helpers

private func url(_ string: String) -> AnyURL {
    AnyURL(string: string)!
}

private func makeReadingOrder(count: Int) -> [Link] {
    (1 ... count).map { Link(href: "chap\($0).html", mediaType: .html) }
}

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
