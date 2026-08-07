//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

enum LocatorAnchoringTests {
    struct SameResource {
        @Test func copiesCSSSelectorAndText() {
            let location = locator(
                href: "chapter1.html",
                progression: 0.4,
                position: 12
            )
            let anchor = locator(
                href: "chapter1.html",
                cssSelector: "#chapter > p:nth-child(3)",
                highlight: "It was a bright cold day in April"
            )

            let result = location.anchored(to: anchor)

            #expect(result.locations.cssSelector == "#chapter > p:nth-child(3)")
            #expect(result.text.highlight == "It was a bright cold day in April")
        }

        @Test func preservesProgressionAndPosition() {
            let location = locator(
                href: "chapter1.html",
                progression: 0.4,
                position: 12
            )
            let anchor = locator(
                href: "chapter1.html",
                cssSelector: "p",
                highlight: "Some text"
            )

            let result = location.anchored(to: anchor)

            #expect(result.href.string == "chapter1.html")
            #expect(result.locations.progression == 0.4)
            #expect(result.locations.position == 12)
        }

        @Test func overwritesPreviousAnchor() {
            let location = locator(
                href: "chapter1.html",
                cssSelector: "#old",
                highlight: "Old text"
            )
            let anchor = locator(
                href: "chapter1.html",
                cssSelector: "#new",
                highlight: "New text"
            )

            let result = location.anchored(to: anchor)

            #expect(result.locations.cssSelector == "#new")
            #expect(result.text.highlight == "New text")
        }

        @Test func clearsAnchorWhenAnchorIsEmpty() {
            let location = locator(
                href: "chapter1.html",
                cssSelector: "#old",
                highlight: "Old text"
            )
            let anchor = locator(href: "chapter1.html")

            let result = location.anchored(to: anchor)

            #expect(result.locations.cssSelector == nil)
            #expect(result.text.highlight == nil)
        }

        @Test func truncatesLongHighlights() {
            let location = locator(href: "chapter1.html", progression: 0.4)
            let anchor = locator(
                href: "chapter1.html",
                cssSelector: "p",
                highlight: String(repeating: "a", count: 500)
            )

            let result = location.anchored(to: anchor)

            #expect(result.text.highlight == String(repeating: "a", count: 200))
        }

        @Test func keepsShortHighlightsIntact() {
            let location = locator(href: "chapter1.html")
            let anchor = locator(
                href: "chapter1.html",
                highlight: "Short highlight"
            )

            let result = location.anchored(to: anchor)

            #expect(result.text.highlight == "Short highlight")
        }

        @Test func equivalentHREFsWithFragment() {
            let location = locator(href: "chapter1.html#section2", progression: 0.4)
            let anchor = locator(
                href: "chapter1.html",
                cssSelector: "p",
                highlight: "Some text"
            )

            let result = location.anchored(to: anchor)

            #expect(result.locations.cssSelector == "p")
            #expect(result.text.highlight == "Some text")
        }
    }

    struct DifferentResource {
        @Test func returnsSelfUnchanged() {
            let location = locator(
                href: "chapter1.html",
                progression: 0.4,
                cssSelector: "#old",
                highlight: "Old text"
            )
            let anchor = locator(
                href: "chapter2.html",
                cssSelector: "#new",
                highlight: "New text"
            )

            let result = location.anchored(to: anchor)

            #expect(result == location)
        }
    }
}

// MARK: - Helpers

private func locator(
    href: String,
    progression: Double? = nil,
    position: Int? = nil,
    cssSelector: String? = nil,
    highlight: String? = nil
) -> Locator {
    var locations = Locator.Locations(
        progression: progression,
        position: position
    )
    locations.cssSelector = cssSelector

    return Locator(
        href: AnyURL(string: href)!,
        mediaType: .xhtml,
        locations: locations,
        text: Locator.Text(highlight: highlight)
    )
}
