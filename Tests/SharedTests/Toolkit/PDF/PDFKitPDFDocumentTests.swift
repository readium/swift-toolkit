//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

struct PDFKitPDFDocumentTests {
    /// `outline-destinations.pdf` targets its pages with each form of
    /// destination, resolving the named destinations with the `/Names /Dests`
    /// name tree.
    @Test func tableOfContentsResolvesEachFormOfDestination() async throws {
        let document = try await open("Toolkit/PDF/outline-destinations.pdf")

        #expect(try await document.tableOfContents() == [
            PDFOutlineNode(title: "Explicit destination", pageNumber: 1, children: [
                PDFOutlineNode(title: "GoTo action", pageNumber: 2, children: []),
                PDFOutlineNode(title: "Named destination to an array", pageNumber: 3, children: []),
            ]),
            // The "Unresolved named destination" child is skipped, with its
            // own child.
            PDFOutlineNode(title: "Named destination to a dictionary", pageNumber: 4, children: [
                PDFOutlineNode(title: "Named destination to a dictionary reference", pageNumber: 5, children: []),
            ]),
        ])
    }

    /// `outline-legacy-destinations.pdf` resolves its named destinations with
    /// the PDF 1.1 `/Dests` dictionary of the catalog. It needs its own
    /// fixture, as PDFKit ignores this dictionary when the document also has a
    /// `/Names /Dests` name tree.
    @Test func tableOfContentsResolvesLegacyNamedDestinations() async throws {
        let document = try await open("Toolkit/PDF/outline-legacy-destinations.pdf")

        #expect(try await document.tableOfContents() == [
            PDFOutlineNode(title: "Legacy named destination", pageNumber: 2, children: []),
        ])
    }

    /// `daisy-truncated.pdf` has no `/Outlines` entry.
    @Test func tableOfContentsIsEmptyWithoutOutline() async throws {
        let document = try await open("Publication/Services/daisy-truncated.pdf")

        #expect(try await document.tableOfContents() == [])
    }

    private func open(_ path: String) async throws -> PDFDocument {
        try await PDFKitPDFDocumentFactory().open(file: Fixtures().url(for: path), password: nil)
    }
}
