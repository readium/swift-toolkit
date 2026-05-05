//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

struct LocatorLocationsPDFTests {
    @Test func pageIsNilWhenNoFragments() {
        #expect(Locator.Locations().page == nil)
    }

    @Test func pageIsNilForUnrelatedFragment() {
        #expect(Locator.Locations(fragments: ["other=5"]).page == nil)
    }

    @Test func pageIsNilForMalformedFragment() {
        #expect(Locator.Locations(fragments: ["page=abc"]).page == nil)
        #expect(Locator.Locations(fragments: ["page="]).page == nil)
        #expect(Locator.Locations(fragments: ["page"]).page == nil)
    }

    @Test func pageIsParsedFromFragment() {
        #expect(Locator.Locations(fragments: ["page=1"]).page == 1)
        #expect(Locator.Locations(fragments: ["page=42"]).page == 42)
    }

    @Test func pageIsParsedFromCompoundFragment() {
        // Handles compound fragment strings like "foo=1&page=42"
        #expect(Locator.Locations(fragments: ["foo=1&page=42"]).page == 42)
        #expect(Locator.Locations(fragments: ["foo=1#page=5"]).page == 5)
    }

    @Test func pageReturnsFirstMatchWhenMultipleFragments() {
        let locations = Locator.Locations(fragments: ["other=3", "page=7", "page=2"])
        #expect(locations.page == 7)
    }
}
