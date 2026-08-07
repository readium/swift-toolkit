//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import Testing

struct DefaultContentServiceTests {
    @Test func reflowablePublicationUsesPlainIterator() throws {
        let publication = makePublication(layout: nil)
        let iterator = try makeIterator(for: publication)
        #expect(!(iterator is SentenceContentIterator))
    }

    @Test func fixedLayoutPublicationUsesSentenceResegmentation() throws {
        let publication = makePublication(layout: .fixed)
        let iterator = try makeIterator(for: publication)
        #expect(iterator is SentenceContentIterator)
    }

    @Test func pdfPublicationUsesSentenceResegmentation() throws {
        let publication = makePublication(layout: nil, mediaType: .pdf)
        let iterator = try makeIterator(for: publication)
        #expect(iterator is SentenceContentIterator)
    }

    private func makePublication(layout: Layout?, mediaType: MediaType = .xhtml) -> Publication {
        Publication(manifest: Manifest(
            metadata: Metadata(title: "Publication", layout: layout),
            readingOrder: [Link(href: "chapter1", mediaType: mediaType)]
        ))
    }

    private func makeIterator(for publication: Publication) throws -> ContentIterator {
        let service = DefaultContentService(
            publication: Weak(publication),
            resourceContentIteratorFactories: []
        )
        let content = try #require(service.content(from: nil))
        return content.iterator()
    }
}
