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

        @Test("fragment: simple quote")
        func fragmentSimpleQuote() {
            #expect(TextSelector.quote(TextQuote(start: "hello")).fragment == ":~:text=hello")
        }

        @Test("fragment: full quote")
        func fragmentFullQuote() {
            #expect(
                TextSelector.quote(TextQuote(before: "before", start: "hello", end: "world", after: "after")).fragment ==
                    ":~:text=before-,hello,world,-after"
            )
        }

        @Test("fragment: position")
        func fragmentPosition() {
            #expect(TextSelector.position(TextPosition(before: "before", after: "after")).fragment == ":~:text=before-,,-after")
        }

        @Test("round-trip: simple quote")
        func roundTripSimpleQuote() {
            let selector = TextSelector.quote(TextQuote(start: "hello"))
            #expect(TextSelector(fragment: selector.fragment) == selector)
        }

        @Test("round-trip: full quote")
        func roundTripFullQuote() {
            let selector = TextSelector.quote(TextQuote(before: "before", start: "hello", end: "world", after: "after"))
            #expect(TextSelector(fragment: selector.fragment) == selector)
        }
    }

    @Suite("TemporalSelector") struct TemporalSelectorTests {
        @Test("position: start only")
        func positionStartOnly() {
            #expect(TemporalSelector(fragment: "t=10.0") == .position(TemporalPosition(time: 10)))
        }

        @Test("clip: start and end")
        func clipStartAndEnd() {
            #expect(
                TemporalSelector(fragment: "t=10.0,20.0") ==
                    .clip(TemporalClip(start: 10, end: 20))
            )
        }

        @Test("clip: end only")
        func clipEndOnly() {
            #expect(
                TemporalSelector(fragment: "t=,20.0") ==
                    .clip(TemporalClip(start: nil, end: 20))
            )
        }

        @Test("npt: prefix stripped")
        func nptPrefixStripped() {
            #expect(
                TemporalSelector(fragment: "t=npt:10.0,20.0") ==
                    .clip(TemporalClip(start: 10, end: 20))
            )
        }

        @Test("clip: start with trailing comma")
        func clipStartWithTrailingComma() {
            #expect(
                TemporalSelector(fragment: "t=10.0,") ==
                    .clip(TemporalClip(start: 10, end: nil))
            )
        }

        @Test("invalid: missing t=")
        func invalidMissingT() {
            #expect(TemporalSelector(fragment: "10,20") == nil)
        }

        @Test("fragment: position")
        func fragmentPosition() {
            #expect(TemporalSelector.position(TemporalPosition(time: 10)).fragment == "t=10.0")
        }

        @Test("fragment: clip start and end")
        func fragmentClipStartAndEnd() {
            #expect(TemporalSelector.clip(TemporalClip(start: 10, end: 20)).fragment == "t=10.0,20.0")
        }

        @Test("fragment: clip start only")
        func fragmentClipStartOnly() {
            #expect(TemporalSelector.clip(TemporalClip(start: 10, end: nil)).fragment == "t=10.0,")
        }

        @Test("fragment: clip end only")
        func fragmentClipEndOnly() {
            #expect(TemporalSelector.clip(TemporalClip(start: nil, end: 20)).fragment == "t=,20.0")
        }

        @Test("round-trip: position")
        func roundTripPosition() {
            let selector = TemporalSelector.position(TemporalPosition(time: 10))
            #expect(TemporalSelector(fragment: selector.fragment) == selector)
        }

        @Test("round-trip: clip")
        func roundTripClip() {
            let selector = TemporalSelector.clip(TemporalClip(start: 10, end: 20))
            #expect(TemporalSelector(fragment: selector.fragment) == selector)
        }
    }

    @Suite("SpatialSelector") struct SpatialSelectorTests {
        @Test("pixel default")
        func pixelDefault() {
            #expect(
                SpatialSelector(fragment: "xywh=10.0,20.0,100.0,50.0") ==
                    SpatialSelector(x: 10, y: 20, width: 100, height: 50, unit: .pixel)
            )
        }

        @Test("explicit pixel unit")
        func explicitPixelUnit() {
            #expect(
                SpatialSelector(fragment: "xywh=pixel:10.0,20.0,100.0,50.0") ==
                    SpatialSelector(x: 10, y: 20, width: 100, height: 50, unit: .pixel)
            )
        }

        @Test("percent unit")
        func percentUnit() {
            #expect(
                SpatialSelector(fragment: "xywh=percent:10.0,20.0,50.0,50.0") ==
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

        @Test("fragment: pixel")
        func fragmentPixel() {
            #expect(SpatialSelector(x: 10, y: 20, width: 100, height: 50, unit: .pixel).fragment == "xywh=10.0,20.0,100.0,50.0")
        }

        @Test("fragment: percent")
        func fragmentPercent() {
            #expect(SpatialSelector(x: 10, y: 20, width: 50, height: 50, unit: .percent).fragment == "xywh=percent:10.0,20.0,50.0,50.0")
        }

        @Test("round-trip: pixel")
        func roundTripPixel() {
            let selector = SpatialSelector(x: 10, y: 20, width: 100, height: 50, unit: .pixel)
            #expect(SpatialSelector(fragment: selector.fragment) == selector)
        }

        @Test("round-trip: percent")
        func roundTripPercent() {
            let selector = SpatialSelector(x: 10, y: 20, width: 50, height: 50, unit: .percent)
            #expect(SpatialSelector(fragment: selector.fragment) == selector)
        }
    }

    @Suite("CSSSelector") struct CSSSelectorTests {
        @Test("id converted to CSS selector")
        func idToCSSSelector() {
            #expect(CSSSelector(fragment: "section1") == CSSSelector(cssSelector: "#section1"))
        }

        @Test("empty URLFragment cannot be constructed")
        func emptyFragmentCannotBeConstructed() {
            #expect(URLFragment(rawValue: "") == nil)
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
                PDFSelector(fragment: "page=3&viewrect=10.0,20.0,100.0,50.0") ==
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
                PDFSelector(fragment: "viewrect=10.0,20.0,100.0,50.0&page=3") ==
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

        @Test("fragment: page only")
        func fragmentPageOnly() {
            #expect(PDFSelector(page: 3).fragment == "page=3")
        }

        @Test("fragment: page with rect")
        func fragmentPageWithRect() {
            #expect(
                PDFSelector(page: 3, rect: PDFSelector.Rect(left: 10, top: 20, width: 100, height: 50)).fragment ==
                    "page=3&viewrect=10.0,20.0,100.0,50.0"
            )
        }

        @Test("round-trip: page only")
        func roundTripPageOnly() {
            let selector = PDFSelector(page: 3)
            #expect(PDFSelector(fragment: selector.fragment) == selector)
        }

        @Test("round-trip: page with rect")
        func roundTripPageWithRect() {
            let selector = PDFSelector(page: 3, rect: PDFSelector.Rect(left: 10, top: 20, width: 100, height: 50))
            #expect(PDFSelector(fragment: selector.fragment) == selector)
        }
    }
}
