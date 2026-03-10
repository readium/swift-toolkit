//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
@testable import ReadiumStreamer
import Testing

@Suite class ReadiumGuidedNavigationServiceTests {
    /// Per-resource GN alternate link.
    lazy var gnLink = Link(
        href: "guided.json",
        mediaType: .readiumGuidedNavigationDocument
    )

    /// Reading order link with a per-resource GN alternate.
    lazy var linkWithGN = Link(
        href: "chapter01.xhtml",
        mediaType: .html,
        alternates: [gnLink]
    )

    /// Reading order link without any GN alternate.
    lazy var linkWithoutGN = Link(
        href: "chapter02.xhtml",
        mediaType: .html
    )

    func makeService(
        readingOrder: [Link],
        guided: [[String: Any]]? = nil
    ) -> ReadiumGuidedNavigationService {
        let manifest = Manifest(
            metadata: Metadata(title: "Test"),
            readingOrder: readingOrder
        )

        let container: Container
        if let guided = guided {
            let json: [String: Any] = ["guided": guided]
            let gnd = try! JSONSerialization.data(withJSONObject: json)
            container = SingleResourceContainer(
                resource: DataResource(data: gnd),
                at: gnLink.url()
            )
        } else {
            container = EmptyContainer()
        }

        return ReadiumGuidedNavigationService(manifest: manifest, container: container)
    }

    // MARK: - hasGuidedNavigation(for:)

    @Test func hasGuidedNavigationFalseForLinkWithoutGN() {
        let service = makeService(readingOrder: [linkWithoutGN])
        #expect(service.hasGuidedNavigation(for: linkWithoutGN) == false)
    }

    @Test func hasGuidedNavigationTrueForLinkWithGNAlternate() {
        let service = makeService(readingOrder: [linkWithGN])
        #expect(service.hasGuidedNavigation(for: linkWithGN) == true)
    }

    @Test func hasGuidedNavigationPublicationLevelTrueWhenAnyLinkHasGN() {
        let service = makeService(readingOrder: [linkWithoutGN, linkWithGN])
        #expect(service.hasGuidedNavigation == true)
    }

    @Test func hasGuidedNavigationPublicationLevelFalseWhenNoLinkHasGN() {
        let service = makeService(readingOrder: [linkWithoutGN])
        #expect(service.hasGuidedNavigation == false)
    }

    // MARK: - guidedNavigationDocument(for:) — per-resource

    @Test func returnsNilForLinkWithoutGN() async throws {
        let service = makeService(readingOrder: [linkWithoutGN])
        let result = await service.guidedNavigationDocument(for: linkWithoutGN)
        #expect(try result.get() == nil)
    }

    @Test func returnsFailureWhenGNDocumentMissingFromContainer() async {
        let service = makeService(readingOrder: [linkWithGN])
        let result = await service.guidedNavigationDocument(for: linkWithGN)
        #expect {
            try result.get()
        } throws: { error in
            guard let readError = error as? ReadError, case .decoding = readError else { return false }
            return true
        }
    }

    @Test func returnsDocumentFromPerResourceAlternate() async throws {
        let guided: [[String: Any]] = [
            ["textref": "chapter01.xhtml#s1"],
        ]
        let service = makeService(readingOrder: [linkWithGN], guided: guided)

        let doc = try await service.guidedNavigationDocument(for: linkWithGN).get()
        #expect(try doc == GuidedNavigationDocument(guided: [
            #require(GuidedNavigationObject(refs: .init(text: AnyURL(string: "chapter01.xhtml#s1")))),
        ]))
    }
}
