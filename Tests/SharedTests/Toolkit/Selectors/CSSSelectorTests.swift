//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

@Suite("CSSSelector") struct CSSSelectorTests {
    @Test("id converted to CSS selector")
    func idToCSSSelector() {
        #expect(CSSSelector(fragment: "section1") == CSSSelector(cssSelector: "#section1"))
    }

    @Suite("init(id:)") struct InitID {
        @Test("produces hash-prefixed CSS selector")
        func producesHashPrefixedSelector() {
            #expect(CSSSelector(id: "section1") == CSSSelector(cssSelector: "#section1"))
        }

        @Test("id with hyphens and underscores")
        func idWithHyphensAndUnderscores() {
            #expect(CSSSelector(id: "my-id_1") == CSSSelector(cssSelector: "#my-id_1"))
        }

        @Test("round-trips through htmlID")
        func roundTripsThroughHtmlID() {
            #expect(CSSSelector(id: "section1").htmlID == "section1")
        }
    }

    @Test("empty URLFragment cannot be constructed")
    func emptyFragmentCannotBeConstructed() {
        #expect(URLFragment(rawValue: "") == nil)
    }

    @Test("htmlID: plain id selector")
    func htmlIDPlain() {
        #expect(CSSSelector(cssSelector: "#section1").htmlID == "section1")
    }

    @Test("htmlID: id with hyphens and underscores")
    func htmlIDHyphensUnderscores() {
        #expect(CSSSelector(cssSelector: "#my-id_1").htmlID == "my-id_1")
    }

    @Test("htmlID: descendant ending in id")
    func htmlIDDescendantEndingInID() {
        #expect(CSSSelector(cssSelector: ".bar #foo").htmlID == "foo")
    }

    @Test("htmlID: id followed by descendant returns nil")
    func htmlIDFollowedByDescendant() {
        #expect(CSSSelector(cssSelector: "#foo .bar").htmlID == nil)
    }

    @Test("htmlID: class selector returns nil")
    func htmlIDClassSelector() {
        #expect(CSSSelector(cssSelector: ".foo").htmlID == nil)
    }

    @Test("htmlID: bare hash returns nil")
    func htmlIDBareHash() {
        #expect(CSSSelector(cssSelector: "#").htmlID == nil)
    }

    @Test("htmlID: round-trips through fragment")
    func htmlIDRoundTrip() {
        let css = CSSSelector(fragment: "section1")
        #expect(css.htmlID == "section1")
    }
}
