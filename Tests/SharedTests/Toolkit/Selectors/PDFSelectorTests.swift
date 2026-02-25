//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

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
