//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumNavigator
import Testing

enum PDFTextMatcherTests {
    struct ExactMatch {
        @Test func findsLiteralQuery() {
            let text = "At the little town of Vevey, in Switzerland"
            let range = PDFTextMatcher.findRange(of: "little town", in: text)
            #expect(range == (text as NSString).range(of: "little town"))
        }

        @Test func returnsNilWhenNotFound() {
            #expect(PDFTextMatcher.findRange(of: "unicorn", in: "At the little town of Vevey") == nil)
        }

        @Test func returnsNilForEmptyQuery() {
            #expect(PDFTextMatcher.findRange(of: "", in: "some text") == nil)
        }

        @Test func returnsNilForWhitespaceOnlyQuery() {
            #expect(PDFTextMatcher.findRange(of: " \n ", in: "some text") == nil)
        }

        @Test func returnsNilForEmptyText() {
            #expect(PDFTextMatcher.findRange(of: "query", in: "") == nil)
        }
    }

    struct Normalization {
        @Test func collapsesWhitespaceRuns() {
            let text = "for the\nentertainment   of\t tourists"
            let range = PDFTextMatcher.findRange(of: "the entertainment of tourists", in: text)
            // The match must cover the original, uncollapsed whitespace.
            #expect(range == NSRange(location: 4, length: 32))
        }

        @Test func skipsSoftHyphens() {
            let text = "a com\u{00AD}fortable inn"
            let range = PDFTextMatcher.findRange(of: "comfortable", in: text)
            // "com" + soft hyphen + "fortable" = 12 UTF-16 units in the original.
            #expect(range == NSRange(location: 2, length: 12))
        }

        @Test func foldsLigatures() {
            let text = "an e\u{FB03}cient plan"
            let range = PDFTextMatcher.findRange(of: "efficient", in: text)
            // "e" + "ﬃ" + "cient" = 7 UTF-16 units in the original.
            #expect(range == NSRange(location: 3, length: 7))
        }

        @Test func matchesAcrossUnicodeNormalizationForms() {
            let text = "un caf\u{00E9} noir" // precomposed é
            let range = PDFTextMatcher.findRange(of: "cafe\u{0301}", in: text) // decomposed é
            #expect(range == NSRange(location: 3, length: 4))
        }

        @Test func mapsOffsetsDeepInThePage() {
            // Every artifact before the match shifts normalized offsets away
            // from the original ones; the returned range must not drift.
            let text = "\u{FB01}rst\u{00AD} line\nsecond \u{FB03}ne   line\nthe target phrase here"
            let range = PDFTextMatcher.findRange(of: "target phrase", in: text)
            #expect(range == (text as NSString).range(of: "target phrase"))
        }
    }

    struct Disambiguation {
        let text = "the cat sat. the cat ran away."

        @Test func fallsBackToFirstOccurrence() {
            let range = PDFTextMatcher.findRange(of: "the cat", in: text)
            #expect(range == NSRange(location: 0, length: 7))
        }

        @Test func beforeContextSelectsLaterOccurrence() {
            let range = PDFTextMatcher.findRange(of: "the cat", in: text, before: "cat sat. ")
            #expect(range == NSRange(location: 13, length: 7))
        }

        @Test func afterContextSelectsLaterOccurrence() {
            let range = PDFTextMatcher.findRange(of: "the cat", in: text, after: " ran away")
            #expect(range == NSRange(location: 13, length: 7))
        }

        @Test func afterContextSelectsFirstOccurrence() {
            let range = PDFTextMatcher.findRange(of: "the cat", in: text, after: " sat.")
            #expect(range == NSRange(location: 0, length: 7))
        }

        @Test func contextWithLayoutArtifactsStillDisambiguates() {
            let messyText = "the cat  sat.\nthe cat ran away."
            let range = PDFTextMatcher.findRange(of: "the cat", in: messyText, before: "cat sat. ")
            #expect(range == NSRange(location: 14, length: 7))
        }
    }
}
