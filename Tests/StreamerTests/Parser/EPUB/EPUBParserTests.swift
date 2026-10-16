//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@_spi(ExperimentalTimeline) import ReadiumShared
@testable import ReadiumStreamer
@_spi(ExperimentalTimeline) import TestSupport
import Testing

struct EPUBParserTests {
    /// All the table of contents entries point to `s04.xhtml`, after the cover
    /// and the navigation document.
    @Test func timelinePlacesTheFirstEntryOfEachResource() async throws {
        let publication = try await parse("childrens-literature.epub")
        let timeline = try #require(await publication.timeline())
        let section = try #require(timeline.items.first)

        #expect(section.title == .text("SECTION IV FAIRY STORIES—MODERN FANTASTIC TALES"))
        #expect(timeline.segments().map(\.item) == [section])
        #expect(timeline.locate(Locator(href: "EPUB/cover.xhtml", mediaType: .xhtml)) == nil)
        #expect(timeline.locate(Locator(href: "EPUB/s04.xhtml", mediaType: .xhtml, locations: .init(progression: 0.8))) == section)
    }
}

// MARK: - Helpers

private func parse(_ filename: String) async throws -> Publication {
    let container = try await ZIPArchiveOpener().open(
        resource: FileResource(file: FileURL(url: TestPublications.url(for: filename))!),
        format: Format(specifications: .zip, .epub, mediaType: .epub, fileExtension: "epub")
    ).get()
    return try await EPUBParser().parse(asset: .container(container), warnings: nil).get().build()
}
