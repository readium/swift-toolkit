//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@_spi(ExperimentalTimeline) import ReadiumShared
@testable import ReadiumStreamer
import Testing
@_spi(ExperimentalTimeline) import TestSupport

struct PDFParserTests {
    /// `outline.pdf` has 4 pages and this outline:
    ///
    /// - Part 1 → page 1
    ///   - Chapter 1 → page 2
    /// - Chapter 2 → page 4
    @Test func timelinePlacesTheOutlineOnThePages() async throws {
        let publication = try await parse("outline.pdf")
        let timeline = try #require(await publication.timeline())
        let href = publication.readingOrder[0].href
        let chapter1 = timeline.items[0].children[0]
        let chapter2 = timeline.items[1]

        #expect(timeline.outline == [
            "0 Part 1 → \(href)#page=1",
            "  1 Chapter 1 → \(href)#page=2",
            "2 Chapter 2 → \(href)#page=4",
        ])
        #expect(chapter1.end?.offset == .page(3))
        #expect(chapter2.end?.offset == .page(4))
        #expect(timeline.locate(Locator(href: href, mediaType: .pdf, locations: .init(fragments: ["page=3"]))) == chapter1)
    }
}

// MARK: - Helpers

private func parse(_ filename: String) async throws -> Publication {
    let asset: Asset = .resource(ResourceAsset(
        resource: FileResource(file: Fixtures().url(for: filename)),
        format: Format(specifications: .pdf, mediaType: .pdf, fileExtension: "pdf")
    ))
    return try await PDFParser(pdfFactory: DefaultPDFDocumentFactory())
        .parse(asset: asset, warnings: nil).get().build()
}
