//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

enum PropertiesEPUBTests {
    struct Contains {
        @Test func noContains() {
            let sut = Properties()
            #expect(sut.contains == [])
        }

        @Test func contains() {
            let sut = Properties(["contains": ["mathml", "onix"]])
            #expect(sut.contains == ["mathml", "onix"])
        }
    }

    struct EPUBLayoutProperty {
        @Test func noLayout() {
            let sut = Properties()
            #expect(sut.epubLayout == nil)
        }

        @Test func layout() {
            let sut = Properties(["layout": "fixed"])
            #expect(sut.epubLayout == .fixed)
        }

        @Test func unknownLayoutValueIsIgnored() {
            let sut = Properties(["layout": "scrolled"])
            #expect(sut.epubLayout == nil)
        }

        @Test func setLayout() {
            var sut = Properties()
            sut.epubLayout = .reflowable
            #expect(sut.otherProperties["layout"] == "reflowable")

            sut.epubLayout = nil
            #expect(sut.otherProperties["layout"] == nil)
        }
    }
}
