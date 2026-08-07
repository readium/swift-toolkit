//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import Testing

enum PageArtifactDetectorTests {
    struct PageNumbers {
        private let detector = PageNumberArtifactDetector()

        @Test func isNeighborFree() {
            #expect(detector.requiresNeighbors == false)
        }

        @Test(arguments: [
            "42",
            "1234",
            "xii",
            "IV",
            "- 42 -",
            "— 42 —",
            "[42]",
            "(42)",
            "Page 42",
            "page 42",
            "p. 42",
            "42 / 300",
            "42 of 300",
        ])
        func detectsPageNumbers(_ text: String) {
            #expect(detector.detectArtifact(in: candidate(text)) == .pageNumber)
        }

        @Test(arguments: [
            "12345",
            "Chapter 42",
            "Hello",
            "A regular sentence.",
            "mmmmmmmmm",
            // Words made of roman digits only are not numerals.
            "civil",
            "did",
            "mild",
            "Mix",
            "",
        ])
        func ignoresRegularText(_ text: String) {
            #expect(detector.detectArtifact(in: candidate(text)) == nil)
        }

        @Test func worksForBothScopes() {
            #expect(detector.detectArtifact(in: candidate("42", scope: .line)) == .pageNumber)
            #expect(detector.detectArtifact(in: candidate("42", scope: .element)) == .pageNumber)
        }
    }

    struct RunningHeaders {
        private let detector = RunningHeaderArtifactDetector()

        @Test func requiresNeighbors() {
            #expect(detector.requiresNeighbors == true)
        }

        @Test func detectsHeaderMatchingPreviousPage() {
            let result = detector.detectArtifact(
                in: candidate("My Great Book", previous: "My Great Book")
            )
            #expect(result == .runningHeader)
        }

        @Test func detectsHeaderMatchingNextPage() {
            let result = detector.detectArtifact(
                in: candidate("My Great Book", next: "My Great Book")
            )
            #expect(result == .runningHeader)
        }

        @Test func matchIgnoresCaseDigitsAndPunctuation() {
            let result = detector.detectArtifact(
                in: candidate("MY GREAT BOOK — 12", previous: "My Great Book, 13")
            )
            #expect(result == .runningHeader)
        }

        @Test func ignoresCandidateWithoutNeighbors() {
            #expect(detector.detectArtifact(in: candidate("My Great Book")) == nil)
        }

        @Test func ignoresDifferentNeighborText() {
            let result = detector.detectArtifact(
                in: candidate("My Great Book", previous: "Some other line")
            )
            #expect(result == nil)
        }

        @Test func ignoresVeryShortMatches() {
            // Too short to be a reliable running header signal.
            #expect(detector.detectArtifact(in: candidate("Ab", previous: "Ab")) == nil)
        }

        @Test func worksForElementScope() {
            let result = detector.detectArtifact(
                in: candidate("My Great Book", previous: "My Great Book", scope: .element)
            )
            #expect(result == .runningHeader)
        }
    }
}

private func candidate(
    _ text: String,
    previous: String? = nil,
    next: String? = nil,
    edge: PageArtifactCandidate.Edge = .tail,
    scope: PageArtifactCandidate.Scope = .line
) -> PageArtifactCandidate {
    PageArtifactCandidate(
        text: text,
        edge: edge,
        scope: scope,
        previousPageEdgeText: previous,
        nextPageEdgeText: next
    )
}
