//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import PDFKit

/// Iterates a PDF `resource`, starting from the given `locator`.
///
/// Extracts text content from PDF pages using PDFKit. Each page is converted to
/// a `TextContentElement` with a proper locator for navigation and TTS.
///
/// If you want to start mid-resource, the `locator` must contain a `position`
/// key in its `Locator.Locations` object indicating the 1-based page number, or
/// a `page=` fragment.
///
/// If you want to start from the end of the resource, the `locator` must have
/// a `progression` of 1.0.
public class PDFResourceContentIterator: ContentIterator {
    /// Factory for a `PDFResourceContentIterator`.
    public class Factory: ResourceContentIteratorFactory {
        private let pdfFactory: PDFDocumentFactory

        public init(pdfFactory: PDFDocumentFactory) {
            self.pdfFactory = pdfFactory
        }

        public func make(
            publication: Publication,
            readingOrderIndex: Int,
            resource: Resource,
            locator: Locator
        ) -> ContentIterator? {
            guard locator.mediaType.matches(.pdf) else {
                return nil
            }

            return PDFResourceContentIterator(
                resource: resource,
                totalProgressionRange: {
                    let positions = await publication.positionsByReadingOrder().getOrNil() ?? []
                    return positions.getOrNil(readingOrderIndex)?
                        .first?.locations.totalProgression
                        .map { start in
                            let end = positions.getOrNil(readingOrderIndex + 1)?
                                .first?.locations.totalProgression
                                ?? 1.0
                            return start ... end
                        }
                },
                locator: locator
            )
        }
    }

    private let resource: Resource
    private let locator: Locator
    private let beforeMaxLength: Int = 50
    private let totalProgressionRange: Task<ClosedRange<Double>?, Never>

    public init(
        resource: Resource,
        totalProgressionRange: @escaping () async -> ClosedRange<Double>?,
        locator: Locator
    ) {
        self.resource = resource
        self.locator = locator
        self.totalProgressionRange = Task { await totalProgressionRange() }
    }

    public func previous() async throws -> ContentElement? {
        let elements = try await elements()
        let index = (currentIndex ?? elements.startIndex) - 1

        guard let content = elements.elements.getOrNil(index) else {
            return nil
        }

        currentIndex = index
        return content
    }

    public func next() async throws -> ContentElement? {
        let elements = try await elements()
        let index = (currentIndex ?? (elements.startIndex - 1)) + 1

        guard let content = elements.elements.getOrNil(index) else {
            return nil
        }

        currentIndex = index
        return content
    }

    private var currentIndex: Int?

    private func elements() async throws -> ParsedElements {
        try await elementsTask.value.get()
    }

    private lazy var elementsTask: Task<Result<ParsedElements, Error>, Never> = Task {
        do {
            let parsed = try await self.extractElements()
            let adjusted = await self.adjustProgressions(of: parsed)
            return .success(adjusted)
        } catch {
            return .failure(error)
        }
    }

    private func extractElements() async throws -> ParsedElements {
        let data = try await resource.read().get()
        guard let pdfDocument = PDFKit.PDFDocument(data: data) else {
            return ParsedElements(elements: [], startIndex: 0)
        }

        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            return ParsedElements(elements: [], startIndex: 0)
        }

        var elements: [ContentElement] = []
        var accumulatedText = ""

        for pageIndex in 0 ..< pageCount {
            guard
                let page = pdfDocument.page(at: pageIndex),
                let pageText = page.string,
                !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                continue
            }

            let pageNumber = pageIndex + 1
            let pageProgression = Double(pageIndex) / Double(pageCount)

            let beforeText = String(accumulatedText.suffix(beforeMaxLength))
            let pageLocator = locator.copy(
                locations: {
                    $0.position = pageNumber
                    $0.progression = pageProgression
                },
                text: {
                    $0 = Locator.Text(
                        after: nil,
                        before: beforeText.isEmpty ? nil : beforeText,
                        highlight: String(pageText.prefix(280))
                    )
                }
            )

            elements.append(TextContentElement(
                locator: pageLocator,
                role: .body,
                segments: [
                    TextContentElement.Segment(
                        locator: pageLocator,
                        text: pageText
                    ),
                ]
            ))

            accumulatedText += pageText + "\n\n"
        }

        let startIndex = computeStartIndex(in: elements, pageCount: pageCount)
        return ParsedElements(elements: elements, startIndex: startIndex)
    }

    private func computeStartIndex(in elements: [ContentElement], pageCount: Int) -> Int {
        if let position = locator.locations.position {
            return elements.firstIndex { $0.locator.locations.position == position } ?? 0
        } else if locator.locations.progression == 1.0 {
            return max(0, elements.count - 1)
        } else if let progression = locator.locations.progression, progression > 0 {
            return elements.lastIndex {
                ($0.locator.locations.progression ?? 0) <= progression
            } ?? 0
        } else {
            return 0
        }
    }

    private func adjustProgressions(of parsed: ParsedElements) async -> ParsedElements {
        let count = Double(parsed.elements.count)
        guard count > 0 else {
            return parsed
        }

        var result = parsed
        let range = await totalProgressionRange.value

        result.elements = parsed.elements.enumerated().map { index, element in
            let progression = Double(index) / count
            let totalProgression = range.map { $0.lowerBound + progression * ($0.upperBound - $0.lowerBound) }

            return TextContentElement(
                locator: element.locator.copy(locations: {
                    $0.progression = progression
                    $0.totalProgression = totalProgression
                }),
                role: (element as? TextContentElement)?.role ?? .body,
                segments: (element as? TextContentElement)?.segments.map { segment in
                    TextContentElement.Segment(
                        locator: segment.locator.copy(locations: {
                            $0.progression = progression
                            $0.totalProgression = totalProgression
                        }),
                        text: segment.text,
                        attributes: segment.attributes
                    )
                } ?? []
            )
        }

        return result
    }

    private struct ParsedElements {
        var elements: [ContentElement]
        var startIndex: Int
    }
}
