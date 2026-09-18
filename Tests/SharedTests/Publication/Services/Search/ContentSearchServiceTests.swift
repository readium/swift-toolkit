//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

enum ContentSearchServiceTests {
    /// Regression tests for https://github.com/readium/swift-toolkit/issues/876
    ///
    /// When an element's text begins with a character that merges with the
    /// preceding grapheme cluster (e.g. a combining mark merging with the
    /// window's space separator), the sliding window's cached character count
    /// used to run ahead of the real `windowText.count`, and offset arithmetic
    /// trapped with "String index is out of bounds".
    struct GraphemeClusterBoundaries {
        /// A publication made of one `TextContentElement` per array of segment
        /// texts, containing the query "夜灯" twice.
        struct Fixture: CustomTestStringConvertible {
            let name: String
            let elements: [[String]]

            var testDescription: String {
                name
            }
        }

        static let fixtures: [Fixture] = [
            Fixture(
                name: "plain content (control)",
                elements: [
                    ["夜灯亮着，街角安静。"],
                    ["猫在窗台上打盹，夜灯映出影子。"],
                ]
            ),
            Fixture(
                name: "element starting with a combining mark",
                elements: [
                    ["夜灯亮着，街角安静。"],
                    ["\u{0301}猫在窗台上打盹，夜灯映出影子。"],
                ]
            ),
            Fixture(
                name: "element starting with a variation selector",
                elements: [
                    ["夜灯亮着，街角安静。"],
                    ["\u{FE0F}猫在窗台上打盹，夜灯映出影子。"],
                ]
            ),
            Fixture(
                name: "segment starting with a combining mark",
                elements: [
                    ["夜灯亮着，街角安静", "\u{0301}，猫在窗台上打盹，夜灯映出影子。"],
                ]
            ),
        ]

        @Test(arguments: fixtures)
        func findsAllMatches(fixture: Fixture) async throws {
            let results = try await search(query: "夜灯", elements: fixture.elements)

            #expect(results.count == 2)
            #expect(results.allSatisfy { $0.text.highlight == "夜灯" })
        }

        /// The merged cluster shifts every character of the entry one position
        /// back in the window. The entry's start offset must account for it,
        /// otherwise a match is attributed to the wrong segment.
        @Test func matchResolvesToTheOwningSegment() async throws {
            let results = try await search(query: "夜灯", elements: [
                ["第一段。"],
                ["\u{0301}abc", "夜灯xyz"],
            ])

            #expect(results.count == 1)
            let result = try #require(results.first)
            #expect(result.text.highlight == "夜灯")
            #expect(result.locations.fragments == ["e1s1"])
        }

        @Test func snippetsAroundAMergedCluster() async throws {
            let results = try await search(query: "abc", elements: [
                ["第一段。"],
                ["\u{0301}abc def"],
            ])

            let result = try #require(results.first)
            #expect(result.text.highlight == "abc")
            #expect(result.text.before == "第一段。 \u{0301}")
            #expect(result.text.after == "def")
        }
    }
}

// MARK: - Helpers

/// Runs a search over a publication whose content is made of one
/// `TextContentElement` per array of segment texts.
private func search(query: String, elements segmentTexts: [[String]]) async throws -> [Locator] {
    let locator = Locator(href: "chap1", mediaType: .html)
    let elements: [ContentElement] = segmentTexts.enumerated().map { elementIndex, texts in
        TextContentElement(
            locator: locator,
            role: .body,
            segments: texts.enumerated().map { segmentIndex, text in
                TextContentElement.Segment(
                    locator: locator.copy(locations: { $0.fragments = ["e\(elementIndex)s\(segmentIndex)"] }),
                    text: text
                )
            }
        )
    }

    let publication = Publication(
        manifest: Manifest(
            metadata: Metadata(title: ""),
            readingOrder: [Link(href: "chap1", mediaType: .html)]
        ),
        servicesBuilder: PublicationServicesBuilder(
            content: { _ in StubContentService(elements: elements) },
            search: ContentSearchService.makeFactory()
        )
    )

    let iterator = try await publication.search(query: query).get()

    var locators: [Locator] = []
    while let batch = try await iterator.next().get() {
        locators.append(contentsOf: batch.locators)
    }
    return locators
}

private final class StubContentService: ContentService {
    private let elements: [ContentElement]

    init(elements: [ContentElement]) {
        self.elements = elements
    }

    func content(from start: Locator?) -> Content? {
        StubContent(elements: elements)
    }

    private struct StubContent: Content {
        let elements: [ContentElement]

        func iterator() -> ContentIterator {
            StubContentIterator(elements: elements)
        }
    }

    private actor StubContentIterator: ContentIterator {
        private let elements: [ContentElement]
        private var index = 0

        init(elements: [ContentElement]) {
            self.elements = elements
        }

        func next() async throws -> ContentElement? {
            guard index < elements.count else {
                return nil
            }
            defer { index += 1 }
            return elements[index]
        }

        func previous() async throws -> ContentElement? {
            nil
        }
    }
}
