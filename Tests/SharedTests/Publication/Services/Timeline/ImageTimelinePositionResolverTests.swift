//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@_spi(ExperimentalTimeline) @testable import ReadiumShared
import Testing

/// Reading order: images `a.jpg` and `b.jpg`.
struct ImageTimelinePositionResolverTests {
    /// A fragment is ignored.
    @Test func linkIsAtTheStartOfItsImage() {
        #expect(resolver.position(of: Link(href: "b.jpg#xywh=0,0,10,10")) == startOfB)
    }

    /// A progression is ignored.
    @Test func locatorIsAtTheStartOfItsImage() {
        #expect(resolver.position(of: locator("b.jpg", progression: 0.5)) == startOfB)
    }

    @Test func outsideTheReadingOrderHasNoPosition() {
        #expect(resolver.position(of: Link(href: "outside.jpg")) == nil)
        #expect(resolver.position(of: locator("outside.jpg")) == nil)
    }

    @Test func lengthIsCountedInPages() throws {
        let end = try #require(resolver.end)

        #expect(end.coordinate == .page(3))
        #expect(resolver.length(from: resolver.bounds(ofResourceAt: 0).start, to: end) == .pages(2))
    }
}

// MARK: - Helpers

private let resolver = ImageTimelinePositionResolver(
    readingOrder: ["a.jpg", "b.jpg"].map { Link(href: $0, mediaType: .jpeg) }
)

private let startOfB = TimelinePosition(
    readingOrderIndex: 1,
    offset: 0,
    coordinate: .page(2),
    progression: 0,
    totalProgression: 0.5
)

private func locator(_ href: String, progression: Double? = nil) -> Locator {
    Locator(href: AnyURL(string: href)!, mediaType: .jpeg, locations: .init(progression: progression))
}
