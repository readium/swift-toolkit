//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

@Suite struct ReferenceFragmentTests {
    @Suite("TextSelector") struct TextSelectorTests {
        @Test("simple start only")
        func simpleStartOnly() {
            #expect(TextSelector(fragment: ":~:text=hello") == .quote(TextQuote(start: "hello")))
        }

        @Test("with prefix")
        func withPrefix() {
            #expect(
                TextSelector(fragment: ":~:text=before-,hello") ==
                    .quote(TextQuote(before: "before", start: "hello"))
            )
        }

        @Test("with start and end")
        func withStartAndEnd() {
            #expect(
                TextSelector(fragment: ":~:text=hello,world") ==
                    .quote(TextQuote(start: "hello", end: "world"))
            )
        }

        @Test("full directive")
        func fullDirective() {
            #expect(
                TextSelector(fragment: ":~:text=before-,hello,world,-after") ==
                    .quote(TextQuote(before: "before", start: "hello", end: "world", after: "after"))
            )
        }

        @Test("percent-encoded components")
        func percentEncoded() {
            #expect(
                TextSelector(fragment: ":~:text=hel%20lo") ==
                    .quote(TextQuote(start: "hel lo"))
            )
        }

        @Test("invalid: no prefix")
        func invalidNoPrefix() {
            #expect(TextSelector(fragment: "text=hello") == nil)
        }

        @Test("invalid: empty start")
        func invalidEmptyStart() {
            #expect(TextSelector(fragment: ":~:text=") == nil)
        }
    }

    @Suite("TemporalSelector") struct TemporalSelectorTests {
        @Test("position: start only")
        func positionStartOnly() {
            #expect(TemporalSelector(fragment: "t=10") == .position(TemporalPosition(time: 10)))
        }

        @Test("clip: start and end")
        func clipStartAndEnd() {
            #expect(
                TemporalSelector(fragment: "t=10,20") ==
                    .clip(TemporalClip(start: 10, end: 20))
            )
        }

        @Test("clip: end only")
        func clipEndOnly() {
            #expect(
                TemporalSelector(fragment: "t=,20") ==
                    .clip(TemporalClip(start: nil, end: 20))
            )
        }

        @Test("npt: prefix stripped")
        func nptPrefixStripped() {
            #expect(
                TemporalSelector(fragment: "t=npt:10,20") ==
                    .clip(TemporalClip(start: 10, end: 20))
            )
        }

        @Test("clip: start with trailing comma")
        func clipStartWithTrailingComma() {
            #expect(
                TemporalSelector(fragment: "t=10,") ==
                    .clip(TemporalClip(start: 10, end: nil))
            )
        }

        @Test("invalid: missing t=")
        func invalidMissingT() {
            #expect(TemporalSelector(fragment: "10,20") == nil)
        }
    }

    @Suite("SpatialSelector") struct SpatialSelectorTests {
        @Test("pixel default")
        func pixelDefault() {
            #expect(
                SpatialSelector(fragment: "xywh=10,20,100,50") ==
                    SpatialSelector(x: 10, y: 20, width: 100, height: 50, unit: .pixel)
            )
        }

        @Test("explicit pixel unit")
        func explicitPixelUnit() {
            #expect(
                SpatialSelector(fragment: "xywh=pixel:10,20,100,50") ==
                    SpatialSelector(x: 10, y: 20, width: 100, height: 50, unit: .pixel)
            )
        }

        @Test("percent unit")
        func percentUnit() {
            #expect(
                SpatialSelector(fragment: "xywh=percent:10,20,50,50") ==
                    SpatialSelector(x: 10, y: 20, width: 50, height: 50, unit: .percent)
            )
        }

        @Test("invalid: missing xywh=")
        func invalidMissingPrefix() {
            #expect(SpatialSelector(fragment: "10,20,100,50") == nil)
        }

        @Test("invalid: wrong component count")
        func invalidWrongComponentCount() {
            #expect(SpatialSelector(fragment: "xywh=10,20,100") == nil)
        }
    }

    @Suite("CSSSelector") struct CSSSelectorTests {
        @Test("id converted to CSS selector")
        func idToCSSSelector() {
            #expect(CSSSelector(fragment: "section1") == CSSSelector(cssSelector: "#section1"))
        }

        @Test("empty returns nil")
        func emptyReturnsNil() {
            #expect(CSSSelector(fragment: "") == nil)
        }
    }

    @Suite("PDFSelector") struct PDFSelectorTests {
        @Test("page only")
        func pageOnly() {
            #expect(PDFSelector(fragment: "page=3") == PDFSelector(page: 3))
        }

        @Test("page with viewrect")
        func pageWithViewrect() {
            #expect(
                PDFSelector(fragment: "page=3&viewrect=10,20,100,50") ==
                    PDFSelector(page: 3, rect: PDFSelector.Rect(left: 10, top: 20, width: 100, height: 50))
            )
        }

        @Test("page with fractional viewrect")
        func pageWithFractionalViewrect() {
            #expect(
                PDFSelector(fragment: "page=3&viewrect=10.5,20.25,100.75,50.1") ==
                    PDFSelector(page: 3, rect: PDFSelector.Rect(left: 10.5, top: 20.25, width: 100.75, height: 50.1))
            )
        }

        @Test("viewrect before page")
        func viewrectBeforePage() {
            #expect(
                PDFSelector(fragment: "viewrect=10,20,100,50&page=3") ==
                    PDFSelector(page: 3, rect: PDFSelector.Rect(left: 10, top: 20, width: 100, height: 50))
            )
        }

        @Test("invalid: missing page")
        func invalidMissingPage() {
            #expect(PDFSelector(fragment: "viewrect=10,20,100,50") == nil)
        }

        @Test("invalid: page not integer")
        func invalidPageNotInteger() {
            #expect(PDFSelector(fragment: "page=abc") == nil)
        }
    }
}
