//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
@testable import ReadiumStreamer
import Testing

@Suite class SMILGuidedNavigationServiceTests {
    let smilData = """
    <?xml version="1.0" encoding="utf-8"?>
    <smil xmlns="http://www.w3.org/ns/SMIL" xmlns:epub="http://www.idpf.org/2007/ops" version="3.0">
      <body>
        <seq id="s1" epub:textref="chapter01.xhtml" epub:type="chapter">
          <par id="p1" epub:type="glossterm">
            <text src="chapter01.xhtml#id_p1"/>
            <audio src="chapter01.mp3" clipBegin="0:00:00.000" clipEnd="0:00:05.123"/>
          </par>
          <seq id="s2" epub:textref="chapter01.xhtml#sec1" epub:type="table">
            <par id="p2">
              <text src="chapter01.xhtml#id_h1"/>
              <audio src="chapter01.mp3" clipBegin="0:00:05.123" clipEnd="0:00:10.000"/>
            </par>
          </seq>
        </seq>
      </body>
    </smil>
    """

    let smilLink = Link(
        href: "OEBPS/chapter01.smil",
        mediaType: .smil
    )

    /// Reading order link with a SMIL alternate.
    lazy var linkWithSMIL = Link(
        href: "OEBPS/chapter01.xhtml",
        mediaType: .html,
        alternates: [smilLink]
    )

    /// Reading order link without any SMIL alternate.
    let linkWithoutSMIL = Link(
        href: "OEBPS/chapter02.xhtml",
        mediaType: .html
    )

    func makeService(readingOrder: [Link], container: Container? = nil) -> SMILGuidedNavigationService {
        let container = container ?? SingleResourceContainer(
            resource: DataResource(string: smilData),
            at: smilLink.url()
        )

        return SMILGuidedNavigationService(readingOrder: readingOrder, container: container)
    }

    // MARK: - hasGuidedNavigation(for:)

    @Test func hasGuidedNavigationFalseForLinkWithoutSMIL() {
        let service = makeService(readingOrder: [linkWithoutSMIL])
        #expect(service.hasGuidedNavigation(for: linkWithoutSMIL) == false)
    }

    @Test func hasGuidedNavigationTrueForLinkWithSMIL() {
        let service = makeService(readingOrder: [linkWithSMIL])
        #expect(service.hasGuidedNavigation(for: linkWithSMIL) == true)
    }

    @Test func hasGuidedNavigationPublicationLevelTrueWhenAnyLinkHasSMIL() {
        let service = makeService(readingOrder: [linkWithoutSMIL, linkWithSMIL])
        #expect(service.hasGuidedNavigation == true)
    }

    @Test func hasGuidedNavigationPublicationLevelFalseWhenNoLinkHasSMIL() {
        let service = makeService(readingOrder: [linkWithoutSMIL])
        #expect(service.hasGuidedNavigation == false)
    }

    // MARK: - guidedNavigationDocument(for:)

    @Test func returnsNilForLinkWithoutSMIL() async throws {
        let service = makeService(readingOrder: [linkWithoutSMIL])
        let result = try await service.guidedNavigationDocument(for: linkWithoutSMIL)
        #expect(result == nil)
    }

    @Test func returnsFailureWhenSMILMissingFromContainer() async {
        let service = makeService(readingOrder: [linkWithSMIL], container: EmptyContainer())
        await #expect(throws: ReadError.self) {
            try await service.guidedNavigationDocument(for: linkWithSMIL)
        }
    }

    @Test func returnsDocumentForLinkWithSMIL() async throws {
        let service = makeService(readingOrder: [linkWithSMIL])
        let doc = try await service.guidedNavigationDocument(for: linkWithSMIL)
        #expect(doc != nil)
        #expect(doc?.guided.isEmpty == false)
    }
}
