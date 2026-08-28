//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreGraphics
@testable import ReadiumNavigator
import Testing

enum PDFRectFragmentTests {
    struct Parsing {
        @Test func highlight() {
            let fragments = PDFRectFragment.parse(fragment: "highlight=10,20,30,5")
            #expect(fragments == [.highlight(left: 10, right: 20, top: 30, bottom: 5)])
        }

        @Test func viewrect() {
            let fragments = PDFRectFragment.parse(fragment: "viewrect=10,20,100,50")
            #expect(fragments == [.viewrect(left: 10, top: 20, width: 100, height: 50)])
        }

        @Test func combinedWithOtherParameters() {
            let fragments = PDFRectFragment.parse(fragment: "page=3&highlight=10,20,30,5")
            #expect(fragments == [.highlight(left: 10, right: 20, top: 30, bottom: 5)])
        }

        @Test func decimalValues() {
            let fragments = PDFRectFragment.parse(fragment: "highlight=10.5,20.25,30,5")
            #expect(fragments == [.highlight(left: 10.5, right: 20.25, top: 30, bottom: 5)])
        }

        @Test func multipleHighlightsPreserveOrder() {
            let fragments = PDFRectFragment.parse(fragments: [
                "page=7",
                "highlight=10,20,30,25",
                "highlight=5,90,25,20",
            ])
            #expect(fragments == [
                .highlight(left: 10, right: 20, top: 30, bottom: 25),
                .highlight(left: 5, right: 90, top: 25, bottom: 20),
            ])
        }

        @Test(arguments: [
            "highlight=10,20,30", // missing value
            "highlight=10,20,30,5,8", // extra value
            "highlight=10,20,30,abc", // not a number
            "highlight", // no values
            "namedest=chapter2", // unrelated parameter
            "page=3", // page fragments are not rects
        ])
        func ignoresMalformedFragments(fragment: String) {
            #expect(PDFRectFragment.parse(fragment: fragment).isEmpty)
        }
    }

    struct RectConversion {
        let pageBounds = CGRect(x: 0, y: 0, width: 432, height: 648)

        @Test func highlightIsInPDFUserSpace() {
            let fragment = PDFRectFragment.highlight(left: 10, right: 20, top: 30, bottom: 5)
            #expect(fragment.rect(inPageBounds: pageBounds) == CGRect(x: 10, y: 5, width: 10, height: 25))
        }

        @Test func viewrectIsFlippedFromTopLeftOrigin() {
            let fragment = PDFRectFragment.viewrect(left: 10, top: 20, width: 100, height: 50)
            #expect(fragment.rect(inPageBounds: pageBounds) == CGRect(x: 10, y: 578, width: 100, height: 50))
        }

        @Test func viewrectAccountsForCropBoxOrigin() {
            let fragment = PDFRectFragment.viewrect(left: 10, top: 20, width: 100, height: 50)
            let bounds = CGRect(x: 90, y: 72, width: 300, height: 500)
            #expect(fragment.rect(inPageBounds: bounds) == CGRect(x: 100, y: 502, width: 100, height: 50))
        }
    }

    struct Generation {
        @Test func highlightFragment() {
            let fragment = PDFRectFragment.highlightFragment(for: CGRect(x: 10, y: 5, width: 10, height: 25))
            #expect(fragment == "highlight=10,20,30,5")
        }

        @Test func dropsTrailingZeros() {
            let fragment = PDFRectFragment.highlightFragment(for: CGRect(x: 10.5, y: 5, width: 9.5, height: 25))
            #expect(fragment == "highlight=10.5,20,30,5")
        }

        @Test func roundTrip() {
            let rect = CGRect(x: 12.25, y: 34.5, width: 56, height: 78.75)
            let fragment = PDFRectFragment.highlightFragment(for: rect)
            let parsed = PDFRectFragment.parse(fragment: fragment)
            #expect(parsed.count == 1)
            #expect(parsed[0].rect(inPageBounds: .zero) == rect)
        }
    }
}
