//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

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
