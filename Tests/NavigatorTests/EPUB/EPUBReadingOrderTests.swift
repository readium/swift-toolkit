//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

enum EPUBReadingOrderTests {
    @Suite("Init") struct Init {
        let xhtml = Link(href: "p1.xhtml", mediaType: .xhtml)
        let jpeg = Link(href: "p1.jpg", mediaType: .jpeg)
        let smil = Link(href: "p1.smil", mediaType: .smil)

        @Test(".default renders the links as authored")
        func defaultVariant() {
            let main = link(xhtml, alternates: [jpeg])
            let sut = EPUBReadingOrder(readingOrder: [main], preferredVariant: .default)
            #expect(sut.links == [main])
        }

        @Test(".html keeps an HTML main link")
        func htmlVariantWithHTMLMain() {
            let main = link(xhtml, alternates: [jpeg])
            let sut = EPUBReadingOrder(readingOrder: [main], preferredVariant: .html)
            #expect(sut.links == [main])
        }

        @Test(".html promotes an HTML alternate")
        func htmlVariantWithHTMLAlternate() {
            let main = link(jpeg, alternates: [xhtml])
            let sut = EPUBReadingOrder(readingOrder: [main], preferredVariant: .html)
            #expect(sut.links[0].href == "p1.xhtml")
            #expect(sut.links[0].mediaType == .xhtml)
            #expect(sut.links[0].alternates == [jpeg])
            #expect(sut.links[0].properties.epubLayout == nil)
        }

        @Test(".image promotes a bitmap alternate")
        func mediaVariant() {
            let main = link(xhtml, alternates: [jpeg])
            let sut = EPUBReadingOrder(readingOrder: [main], preferredVariant: .image)
            #expect(sut.links[0].href == "p1.jpg")
            #expect(sut.links[0].mediaType == .jpeg)
            #expect(sut.links[0].alternates == [xhtml])
        }

        @Test("keeps the main link when no alternate matches", arguments: [EPUBResourceVariant.html, .image])
        func noMatchingAlternate(variant: EPUBResourceVariant) {
            let main = link(Link(href: "p1.pdf", mediaType: .pdf), alternates: [smil])
            let sut = EPUBReadingOrder(readingOrder: [main], preferredVariant: variant)
            #expect(sut.links == [main])
        }

        @Test("transfers the title, rels and properties of the main link")
        func transfersMainFields() {
            var main = link(xhtml, alternates: [
                Link(href: "p1.jpg", mediaType: .jpeg, title: "Alternate", properties: Properties(["page": "right"]), height: 100, width: 50),
            ])
            main.title = "Main"
            main.rels = [.cover]
            main.properties.page = .left

            let sut = EPUBReadingOrder(readingOrder: [main], preferredVariant: .image)

            #expect(sut.links[0].title == "Main")
            #expect(sut.links[0].rels == [.cover])
            #expect(sut.links[0].properties.page == .left)
            #expect(sut.links[0].height == 100)
            #expect(sut.links[0].width == 50)
        }

        @Test("keeps the other alternates after the demoted main link")
        func reordersAlternates() {
            let main = link(xhtml, alternates: [smil, jpeg])
            let sut = EPUBReadingOrder(readingOrder: [main], preferredVariant: .image)
            #expect(sut.links[0].alternates == [xhtml, smil])
        }

        @Test("removes only the promoted alternate among duplicates")
        func duplicateAlternates() {
            let main = link(xhtml, alternates: [jpeg, jpeg])
            let sut = EPUBReadingOrder(readingOrder: [main], preferredVariant: .image)
            #expect(sut.links[0].alternates == [xhtml, jpeg])
        }
    }

    @Suite("Index of HREF") struct IndexOfHREF {
        let sut = EPUBReadingOrder(
            readingOrder: [
                link(Link(href: "p1.xhtml", mediaType: .xhtml), alternates: [Link(href: "p1.jpg", mediaType: .jpeg)]),
                link(Link(href: "p2.xhtml", mediaType: .xhtml), alternates: [Link(href: "p3.xhtml", mediaType: .xhtml)]),
                Link(href: "p3.xhtml", mediaType: .xhtml),
            ],
            preferredVariant: .default
        )

        @Test("matches a rendered link")
        func matchesRenderedLink() {
            #expect(sut.index(of: AnyURL(string: "p2.xhtml")!) == 1)
        }

        @Test("matches an alternate")
        func matchesAlternate() {
            #expect(sut.index(of: AnyURL(string: "p1.jpg")!) == 0)
        }

        @Test("a rendered link wins over an alternate of an earlier link")
        func renderedLinkWins() {
            #expect(sut.index(of: AnyURL(string: "p3.xhtml")!) == 2)
        }

        @Test("ignores the query and fragment", arguments: [
            ("p2.xhtml#id", 1),
            ("p1.jpg?q=1#id", 0),
        ])
        func queryAndFragmentFallback(href: String, expected: Int) {
            #expect(sut.index(of: AnyURL(string: href)!) == expected)
        }

        @Test("returns nil for an unknown href")
        func unknownHREF() {
            #expect(sut.index(of: AnyURL(string: "unknown.xhtml")!) == nil)
        }
    }

    @Suite("Resolve locator") struct ResolveLocator {
        let readingOrder = [
            Link(href: "p0.xhtml", mediaType: .xhtml),
            link(Link(href: "p1.xhtml", mediaType: .xhtml), alternates: [Link(href: "p1.jpg", mediaType: .jpeg)]),
        ]

        let textLocator = Locator(
            href: AnyURL(string: "p1.xhtml")!,
            mediaType: .xhtml,
            locations: .init(
                fragments: ["id"],
                progression: 0.5,
                totalProgression: 0.75,
                position: 2,
                otherLocations: ["cssSelector": "#id"]
            ),
            text: .init(highlight: "Hello")
        )

        @Test("resolves a text locator to the rendered bitmap")
        func textLocatorToBitmap() throws {
            let sut = EPUBReadingOrder(readingOrder: readingOrder, preferredVariant: .image)
            let result = try #require(sut.resolve(textLocator))

            #expect(result.index == 1)
            #expect(result.locator.href.string == "p1.jpg")
            #expect(result.locator.mediaType == .jpeg)
            #expect(result.locator.locations.fragments.isEmpty)
            #expect(result.locator.locations.otherLocations.isEmpty)
            #expect(result.locator.locations.progression == 0.5)
            #expect(result.locator.locations.totalProgression == 0.75)
            #expect(result.locator.locations.position == 2)
        }

        @Test("keeps a locator targeting the rendered link unchanged")
        func unchangedLocator() throws {
            let sut = EPUBReadingOrder(readingOrder: readingOrder, preferredVariant: .html)
            let result = try #require(sut.resolve(textLocator))

            #expect(result.index == 1)
            #expect(result.locator == textLocator)
        }

        @Test("resolves a bitmap locator to the rendered HTML")
        func bitmapLocatorToHTML() throws {
            let sut = EPUBReadingOrder(readingOrder: readingOrder, preferredVariant: .html)
            let locator = Locator(href: AnyURL(string: "p1.jpg")!, mediaType: .jpeg, locations: .init(progression: 0))
            let result = try #require(sut.resolve(locator))

            #expect(result.index == 1)
            #expect(result.locator.href.string == "p1.xhtml")
            #expect(result.locator.mediaType == .xhtml)
            #expect(result.locator.locations.progression == 0)
        }

        @Test("returns nil for an unknown href")
        func unknownHREF() {
            let sut = EPUBReadingOrder(readingOrder: readingOrder, preferredVariant: .image)
            let locator = Locator(href: AnyURL(string: "unknown.xhtml")!, mediaType: .xhtml)
            #expect(sut.resolve(locator) == nil)
        }
    }
}

// MARK: - Helpers

private func link(_ link: Link, alternates: [Link]) -> Link {
    var link = link
    link.alternates = alternates
    return link
}
