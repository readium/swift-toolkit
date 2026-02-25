//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

private let href = AnyURL(string: "res.html")!

@Suite("WebReference.isRefined") struct WebReferenceIsRefinedTests {
    @Test("bare href") func bareHref() {
        #expect(WebReference(href: href).isRefined == false)
    }

    @Test("progression nil") func progressionNil() {
        #expect(WebReference(href: href, progression: nil).isRefined == false)
    }

    @Test("progression 0") func progressionZero() {
        #expect(WebReference(href: href, progression: 0).isRefined == false)
    }

    @Test("progression > 0") func progressionPositive() {
        #expect(WebReference(href: href, progression: 0.5).isRefined == true)
    }

    @Test("text set") func textSet() {
        let text = TextSelector.quote(TextQuote(start: "hello"))
        #expect(WebReference(href: href, text: text).isRefined == true)
    }

    @Test("cssSelector set") func cssSelectorSet() {
        let css = CSSSelector(cssSelector: "#section1")
        #expect(WebReference(href: href, cssSelector: css).isRefined == true)
    }
}

@Suite("AudioReference.isRefined") struct AudioReferenceIsRefinedTests {
    @Test("no temporal") func noTemporal() {
        #expect(AudioReference(href: href).isRefined == false)
    }

    @Test("position at 0") func positionAtZero() {
        #expect(AudioReference(href: href, temporal: .position(TemporalPosition(time: 0))).isRefined == false)
    }

    @Test("position > 0") func positionPositive() {
        #expect(AudioReference(href: href, temporal: .position(TemporalPosition(time: 5))).isRefined == true)
    }

    @Test("clip start 0 end nil") func clipStartZeroEndNil() {
        #expect(AudioReference(href: href, temporal: .clip(TemporalClip(start: 0, end: nil))).isRefined == false)
    }

    @Test("clip start 0 end set") func clipStartZeroEndSet() {
        #expect(AudioReference(href: href, temporal: .clip(TemporalClip(start: 0, end: 10))).isRefined == true)
    }

    @Test("clip start > 0") func clipStartPositive() {
        #expect(AudioReference(href: href, temporal: .clip(TemporalClip(start: 5, end: nil))).isRefined == true)
    }
}

@Suite("ImageReference.isRefined") struct ImageReferenceIsRefinedTests {
    @Test("no spatial") func noSpatial() {
        #expect(ImageReference(href: href).isRefined == false)
    }

    @Test("spatial set") func spatialSet() {
        let spatial = SpatialSelector(x: 10, y: 20, width: 50, height: 50, unit: .pixel)
        #expect(ImageReference(href: href, spatial: spatial).isRefined == true)
    }
}

@Suite("PDFReference.isRefined") struct PDFReferenceIsRefinedTests {
    @Test("bare href") func bareHref() {
        #expect(PDFReference(href: href).isRefined == false)
    }

    @Test("progression 0") func progressionZero() {
        #expect(PDFReference(href: href, progression: 0).isRefined == false)
    }

    @Test("progression > 0") func progressionPositive() {
        #expect(PDFReference(href: href, progression: 0.5).isRefined == true)
    }

    @Test("text set") func textSet() {
        let text = TextSelector.quote(TextQuote(start: "hello"))
        #expect(PDFReference(href: href, text: text).isRefined == true)
    }

    @Test("page 1 no rect") func pageOneNoRect() {
        #expect(PDFReference(href: href, page: PDFSelector(page: 1)).isRefined == false)
    }

    @Test("page > 1") func pageGreaterThanOne() {
        #expect(PDFReference(href: href, page: PDFSelector(page: 2)).isRefined == true)
    }

    @Test("page 1 with rect") func pageOneWithRect() {
        let rect = PDFSelector.Rect(left: 0, top: 0, width: 100, height: 100)
        #expect(PDFReference(href: href, page: PDFSelector(page: 1, rect: rect)).isRefined == true)
    }
}
