//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public enum PDFResourceContentIteratorError: Error {
    /// The publication must have a ``PDFDocumentService`` to open the document.
    case missingPDFDocumentService
}

/// Iterates a PDF resource, starting from the given `locator`.
///
/// Extracts text content from PDF pages. Each page is converted to a
/// `TextContentElement` with a proper locator for navigation and TTS.
///
/// If you want to start mid-resource, the `locator` must contain a `position`
/// key in its `Locator.Locations` object indicating the 1-based page number, a
/// `page=` fragment, or a `progression` value.
///
/// If you want to start from the end of the resource, the `locator` must have
/// a `progression` of 1.0.
///
/// This ``ContentIterator`` requires the ``Publication`` to have a
/// ``PDFDocumentService``.
///
/// - Note: This iterator is intended for single-consumer use. Concurrent calls
///   to `next()` or `previous()` from multiple tasks are not safe.
public class PDFResourceContentIterator: ContentIterator, Loggable {
    
    /// Factory for a `PDFResourceContentIterator`.
    public class Factory: ResourceContentIteratorFactory {
        public init() {}

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
                openDocument: {
                    guard let service = publication.pdfDocumentService else {
                        throw PDFResourceContentIteratorError.missingPDFDocumentService
                    }
                    return try await service.openDocument(at: locator.href)
                },
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

    private let openDocument: () async throws -> PDFDocument
    private let locator: Locator
    private let beforeMaxLength: Int = 50
    private let totalProgressionRange: Task<ClosedRange<Double>?, Never>

    init(
        openDocument: @escaping () async throws -> PDFDocument,
        totalProgressionRange: @escaping () async -> ClosedRange<Double>?,
        locator: Locator
    ) {
        self.openDocument = openDocument
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
        let document = try await openDocument()

        guard let textDocument = document as? PDFDocumentTextProviding else {
            log(.warning, "The PDF document does not support text extraction; no content elements will be produced.")
            return ParsedElements(elements: [], startIndex: 0)
        }

        let pageCount = try await textDocument.pageCount()
        guard pageCount > 0 else {
            return ParsedElements(elements: [], startIndex: 0)
        }

        var elements: [TextContentElement] = []
        var suffixBuffer = ""

        for pageIndex in 0 ..< pageCount {
            guard
                let pageText = try await textDocument.pageText(at: pageIndex),
                !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                continue
            }

            let pageNumber = pageIndex + 1
            let pageProgression = Double(pageIndex) / Double(pageCount)

            let beforeText = String(suffixBuffer.suffix(beforeMaxLength))
            let pageLocator = locator.copy(
                locations: {
                    $0.fragments = ["page=\(pageNumber)"]
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

            let newContent = pageText + "\n\n"
            suffixBuffer = String((suffixBuffer + newContent).suffix(beforeMaxLength))
        }

        let startIndex = computeStartIndex(in: elements)
        return ParsedElements(elements: elements, startIndex: startIndex)
    }

    private func computeStartIndex(in elements: [TextContentElement]) -> Int {
        if let position = locator.locations.position {
            return elements.firstIndex { $0.locator.locations.position == position } ?? 0
        } else if let page = locator.locations.page {
            return elements.firstIndex { $0.locator.locations.page == page } ?? 0
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

        result.elements = parsed.elements.map { element in
            let progression = element.locator.locations.progression ?? 0
            let totalProgression = range.map { $0.lowerBound + progression * ($0.upperBound - $0.lowerBound) }

            return TextContentElement(
                locator: element.locator.copy(locations: {
                    $0.progression = progression
                    $0.totalProgression = totalProgression
                }),
                role: element.role,
                segments: element.segments.map { segment in
                    TextContentElement.Segment(
                        locator: segment.locator.copy(locations: {
                            $0.progression = progression
                            $0.totalProgression = totalProgression
                        }),
                        text: segment.text,
                        attributes: segment.attributes
                    )
                }
            )
        }

        return result
    }

    private struct ParsedElements {
        var elements: [TextContentElement]
        var startIndex: Int
    }
}
