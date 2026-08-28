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
        @Test func elementStartingWithCombiningMark() async throws {
            let results = try await search(query: "夜灯", elements: [
                ["夜灯亮着，街角安静。"],
                ["\u{0301}猫在窗台上打盹，夜灯映出影子。"],
            ])

            #expect(results.count == 2)
            #expect(results.allSatisfy { $0.text.highlight == "夜灯" })
        }

        @Test func elementStartingWithVariationSelector() async throws {
            let results = try await search(query: "夜灯", elements: [
                ["夜灯亮着，街角安静。"],
                ["\u{FE0F}猫在窗台上打盹，夜灯映出影子。"],
            ])

            #expect(results.count == 2)
            #expect(results.allSatisfy { $0.text.highlight == "夜灯" })
        }

        /// A segment starting with a combining mark merges with the last
        /// character of the previous segment inside the same element.
        @Test func segmentStartingWithCombiningMark() async throws {
            let results = try await search(query: "夜灯", elements: [
                ["夜灯亮着，街角安静", "\u{0301}，猫在窗台上打盹，夜灯映出影子。"],
            ])

            #expect(results.count == 2)
            #expect(results.allSatisfy { $0.text.highlight == "夜灯" })
        }

        /// Control: the same content without any cluster-merging character.
        @Test func plainContent() async throws {
            let results = try await search(query: "夜灯", elements: [
                ["夜灯亮着，街角安静。"],
                ["猫在窗台上打盹，夜灯映出影子。"],
            ])

            #expect(results.count == 2)
            #expect(results.allSatisfy { $0.text.highlight == "夜灯" })
        }
    }
}

// MARK: - Helpers

/// Runs a search over a publication whose content is made of one
/// `TextContentElement` per array of segment texts.
private func search(query: String, elements segmentTexts: [[String]]) async throws -> [Locator] {
    let locator = Locator(href: "chap1", mediaType: .html)
    let elements: [ContentElement] = segmentTexts.map { texts in
        TextContentElement(
            locator: locator,
            role: .body,
            segments: texts.map { TextContentElement.Segment(locator: locator, text: $0) }
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
