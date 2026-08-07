//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

enum HardBreakDetectorTests {
    struct SpacedCaps {
        private let detector = SpacedCapsHardBreakDetector()

        @Test(
            "All-caps display lines break",
            arguments: [
                "P A R T O N E",
                "PROLOGUE",
                "PART ONE",
                "THE END",
                "CHAPTER 12",
            ]
        )
        func breaks(text: String) {
            #expect(detector.isHardBreak(HardBreakCandidate(text: text)))
        }

        @Test(
            "Regular text does not break",
            arguments: [
                // Terminal punctuation: a shouted sentence, not a heading.
                "STOP RIGHT THERE!",
                "IT WAS OVER.",
                // Mixed-case lines containing acronyms.
                "NASA launched the rocket",
                "He works at the FBI",
                // Fewer than 3 uppercase letters: page numbers, initials.
                "42",
                "IV",
                "A B",
                // Case-less scripts have no lowercase letters either.
                "これは長い文章で",
                // Longer than 60 characters.
                String(repeating: "A", count: 61),
            ]
        )
        func doesNotBreak(text: String) {
            #expect(!detector.isHardBreak(HardBreakCandidate(text: text)))
        }
    }

    struct Heading {
        private let detector = HeadingHardBreakDetector()

        @Test(
            "Chapter-style lines break",
            arguments: [
                "Chapter 1",
                "Chapter 12",
                "chapter 3",
                "Part II",
                "Section 4",
                "Prologue",
                "Epilogue",
                "Act 2",
                "Scene IV",
            ]
        )
        func breaks(text: String) {
            #expect(detector.isHardBreak(HardBreakCandidate(text: text)))
        }

        @Test(
            "Regular text does not break",
            arguments: [
                // A sentence starting with a heading word.
                "Part of the reason was obvious",
                "Chapter after chapter went by",
                "Act now",
                // Terminal punctuation.
                "Chapter 1.",
                "The chapter ends here.",
            ]
        )
        func doesNotBreak(text: String) {
            #expect(!detector.isHardBreak(HardBreakCandidate(text: text)))
        }

        @Test func headingRoleAlwaysBreaks() {
            #expect(detector.isHardBreak(HardBreakCandidate(
                text: "There Lived a Dragon",
                role: .heading(level: 1)
            )))
        }

        @Test func bodyRoleDoesNotBreakOnItsOwn() {
            #expect(!detector.isHardBreak(HardBreakCandidate(
                text: "There Lived a Dragon",
                role: .body
            )))
        }
    }

    struct StandalonePage {
        private let detector = StandalonePageHardBreakDetector()

        @Test(
            "Short title-cased standalone pages break",
            arguments: [
                "The Great Gatsby",
                "The Lord of the Rings",
                "Bella",
            ]
        )
        func breaks(text: String) {
            #expect(detector.isHardBreak(HardBreakCandidate(text: text, isWholePage: true)))
        }

        @Test func requiresWholePage() {
            #expect(!detector.isHardBreak(HardBreakCandidate(
                text: "The Great Gatsby",
                isWholePage: false
            )))
        }

        @Test(
            "Mid-sentence or regular pages do not break",
            arguments: [
                // Terminal punctuation: a regular short page.
                "It was over.",
                // Starts lowercase: continuation of a sentence from the
                // previous page.
                "and only reachable by boat",
                // Ends with a word cut.
                "There is a particu-",
                // Not title-cased: a sentence spilling onto the next page.
                "The story begins with something very",
                "The hungry cat sat on",
            ]
        )
        func doesNotBreak(text: String) {
            #expect(!detector.isHardBreak(HardBreakCandidate(text: text, isWholePage: true)))
        }
    }
}
