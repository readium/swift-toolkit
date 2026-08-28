//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import PDFKit
@testable import ReadiumNavigator
import ReadiumShared
import Testing

enum PDFDecorationResolverTests {
    @MainActor
    struct RectFragments {
        @Test func rendersDirectlyWithNoTextSearch() throws {
            let rects = try PDFDecorationResolver.resolveRects(
                for: makeLocator(fragments: ["page=7", "highlight=10,20,30,5"]),
                on: textPage()
            )
            #expect(rects == [CGRect(x: 10, y: 5, width: 10, height: 25)])
        }

        @Test func supportsOneHighlightFragmentPerLine() throws {
            let rects = try PDFDecorationResolver.resolveRects(
                for: makeLocator(fragments: ["page=7", "highlight=100,400,600,588", "highlight=36,150,588,576"]),
                on: textPage()
            )
            #expect(rects == [
                CGRect(x: 100, y: 588, width: 300, height: 12),
                CGRect(x: 36, y: 576, width: 114, height: 12),
            ])
        }

        @Test func takesPriorityOverTextHighlight() throws {
            let rects = try PDFDecorationResolver.resolveRects(
                for: makeLocator(fragments: ["highlight=10,20,30,5"], highlight: "text which does not exist on the page"),
                on: textPage()
            )
            #expect(rects == [CGRect(x: 10, y: 5, width: 10, height: 25)])
        }
    }

    @MainActor
    struct TextSearch {
        @Test func resolvesLineBoxesForTextOnThePage() throws {
            let page = try textPage()
            let pageBounds = page.bounds(for: .cropBox)
            let rects = try #require(PDFDecorationResolver.resolveRects(
                for: makeLocator(highlight: "comfortable hotel"),
                on: page
            ))
            #expect(!rects.isEmpty)
            for rect in rects {
                #expect(pageBounds.contains(rect))
                #expect(rect.height < pageBounds.height / 10, "expected a line box, not a page-level rect")
            }
        }

        @Test func textSpanningSeveralLinesYieldsOneBoxPerLine() throws {
            let rects = try #require(try PDFDecorationResolver.resolveRects(
                for: makeLocator(highlight: "for the entertainment of tourists"),
                on: textPage()
            ))
            #expect(rects.count == 2)
        }

        @Test func unresolvableTextRendersNothing() throws {
            // A failed search must never degrade into a full-page highlight.
            let rects = try PDFDecorationResolver.resolveRects(
                for: makeLocator(highlight: "text which does not exist on the page"),
                on: textPage()
            )
            #expect(rects == nil)
        }

        @Test func missingTextLayerRendersNothing() throws {
            let rects = try PDFDecorationResolver.resolveRects(
                for: makeLocator(highlight: "comfortable hotel"),
                on: scannedPage()
            )
            #expect(rects == nil)
        }
    }

    @MainActor
    struct PageLevel {
        @Test func locatorWithNoTextAndNoRectsIsPageLevel() throws {
            let page = try textPage()
            let rects = PDFDecorationResolver.resolveRects(
                for: makeLocator(fragments: ["page=7"]),
                on: page
            )
            #expect(rects == [page.bounds(for: .cropBox)])
        }
    }
}

// MARK: - Helpers

/// Page 6 of the fixture contains the first page of text of Daisy Miller,
/// starting with "At the little town of Vevey, in Switzerland, there is a
/// particu-\nlarly comfortable hotel. There are, indeed, many hotels, for
/// the\nentertainment of tourists [...]". Its crop box is 432x648 with a zero
/// origin.
@MainActor
private func textPage() throws -> PDFPage {
    try #require(fixtureDocument().page(at: 6))
}

/// Page 0 of the fixture has no text layer, like a scanned PDF.
@MainActor
private func scannedPage() throws -> PDFPage {
    try #require(fixtureDocument().page(at: 0))
}

@MainActor
private func fixtureDocument() throws -> PDFKit.PDFDocument {
    let url = try #require(Bundle.module.url(forResource: "daisy-truncated", withExtension: "pdf", subdirectory: "Fixtures"))
    let document: PDFKit.PDFDocument? = PDFKit.PDFDocument(url: url)
    return try #require(document)
}

private func makeLocator(fragments: [String] = [], highlight: String? = nil) -> Locator {
    Locator(
        href: AnyURL(string: "publication.pdf")!,
        mediaType: .pdf,
        locations: .init(fragments: fragments),
        text: .init(highlight: highlight)
    )
}
