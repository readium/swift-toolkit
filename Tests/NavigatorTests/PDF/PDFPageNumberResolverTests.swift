//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

struct PDFPageNumberResolverTests {
    @Test("resolves from page fragment")
    func resolvesFromPageFragment() {
        let locator = Locator(
            href: AnyURL(string: "doc.pdf")!,
            mediaType: .pdf,
            locations: .init(fragments: ["foo=1&page=42"])
        )

        let page = PDFPageNumberResolver.resolve(
            from: locator,
            readingOrderIndex: 0,
            positionsByReadingOrder: nil,
            documentPageCount: nil
        )

        #expect(page == 42)
    }

    @Test("resolves from progression using positions")
    func resolvesFromProgressionUsingPositions() {
        let locator = Locator(
            href: AnyURL(string: "doc.pdf")!,
            mediaType: .pdf,
            locations: .init(progression: 0.6)
        )
        let positions: [[Locator]] = [[
            Locator(href: AnyURL(string: "doc.pdf")!, mediaType: .pdf, locations: .init(fragments: ["page=1"], progression: 0.0, position: 1)),
            Locator(href: AnyURL(string: "doc.pdf")!, mediaType: .pdf, locations: .init(fragments: ["page=2"], progression: 0.5, position: 2)),
            Locator(href: AnyURL(string: "doc.pdf")!, mediaType: .pdf, locations: .init(fragments: ["page=3"], progression: 1.0, position: 3)),
        ]]

        let page = PDFPageNumberResolver.resolve(
            from: locator,
            readingOrderIndex: 0,
            positionsByReadingOrder: positions,
            documentPageCount: nil
        )

        #expect(page == 2)
    }

    @Test("resolves from progression using document page count fallback")
    func resolvesFromProgressionUsingDocumentPageCountFallback() {
        let locator = Locator(
            href: AnyURL(string: "doc.pdf")!,
            mediaType: .pdf,
            locations: .init(progression: 0.55)
        )

        let page = PDFPageNumberResolver.resolve(
            from: locator,
            readingOrderIndex: 0,
            positionsByReadingOrder: nil,
            documentPageCount: 10
        )

        #expect(page == 6)
    }
}
