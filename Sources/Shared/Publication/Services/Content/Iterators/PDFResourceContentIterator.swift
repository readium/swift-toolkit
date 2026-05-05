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
/// If you want to start mid-resource, the `locator` must contain a `page=`
/// fragment, `position`, or a `progression` value.
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
                resourceInfo: {
                    let positions = await publication.positionsByReadingOrder().getOrNil() ?? []
                    let resourcePositions = positions.getOrNil(readingOrderIndex)
                    return ResourceInfo(
                        positionOffset: (resourcePositions?.first?.locations.position ?? 1) - 1,
                        totalProgressionRange: resourcePositions?.first?.locations.totalProgression
                            .map { start -> ClosedRange<Double> in
                                let end = positions.getOrNil(readingOrderIndex + 1)?
                                    .first?.locations.totalProgression ?? 1.0
                                return start ... end
                            }
                    )
                },
                locator: locator
            )
        }
    }

    /// Holds per-resource metadata needed to produce correct global locators.
    struct ResourceInfo {
        
        /// Number of positions that precede this resource in the publication.
        /// Added to each local page number to produce the global `position`.
        var positionOffset: Int
        
        /// Range of `totalProgression` values occupied by this resource, used
        /// to map intra-resource progressions to publication-wide progressions.
        var totalProgressionRange: ClosedRange<Double>?
    }

    /// Async closure that opens and returns the ``PDFDocument`` for this
    /// resource.
    private let openDocument: () async throws -> PDFDocument
    
    /// Starting position within the resource.
    private let locator: Locator
    
    /// Async closure that returns the ``ResourceInfo`` for this resource.
    /// Called at most once, lazily, when content is first requested.
    private let makeResourceInfo: () async -> ResourceInfo

    private let beforeMaxLength: Int = 50
    
    init(
        openDocument: @escaping () async throws -> PDFDocument,
        resourceInfo: @escaping () async -> ResourceInfo,
        locator: Locator
    ) {
        self.openDocument = openDocument
        self.locator = locator
        self.makeResourceInfo = resourceInfo
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
            let info = await self.makeResourceInfo()
            let parsed = try await self.extractElements(resourceInfo: info)
            let adjusted = await self.adjustProgressions(of: parsed, resourceInfo: info)
            return .success(adjusted)
        } catch {
            return .failure(error)
        }
    }

    /// Extracts a ``TextContentElement`` per non-empty page from the PDF
    /// document.
    ///
    /// Page positions are expressed as global publication positions by adding
    /// `resourceInfo.positionOffset` to each 1-based local page number.
    ///
    /// - Parameter resourceInfo: Metadata used to compute global positions and progressions.
    /// - Returns: The parsed elements together with the index of the starting element
    ///   determined from `locator`.
    private func extractElements(resourceInfo: ResourceInfo) async throws -> ParsedElements {
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
                    $0.position = resourceInfo.positionOffset + pageNumber
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
            if newContent.count >= beforeMaxLength {
                suffixBuffer = String(newContent.suffix(beforeMaxLength))
            } else {
                suffixBuffer = String((suffixBuffer + newContent).suffix(beforeMaxLength))
            }
        }

        let startIndex = computeStartIndex(in: elements)
        return ParsedElements(elements: elements, startIndex: startIndex)
    }

    /// Determines the index of the first element to yield from the locator.
    ///
    /// Priority: `page=` fragment → global `position` → `progression == 1.0` (last page) →
    /// largest element whose progression ≤ the requested progression → 0.
    private func computeStartIndex(in elements: [TextContentElement]) -> Int {
        if let page = locator.locations.page {
            return elements.firstIndex { $0.locator.locations.page == page } ?? 0
        } else if let position = locator.locations.position {
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

    /// Rewrites the `progression` and `totalProgression` of every element and segment in `parsed`.
    ///
    /// `progression` is left as-is (already a 0–1 fraction within the resource).
    /// `totalProgression` is mapped into `resourceInfo.totalProgressionRange` so it represents
    /// a publication-wide fraction. If `totalProgressionRange` is `nil`, `totalProgression`
    /// is left unset.
    private func adjustProgressions(of parsed: ParsedElements, resourceInfo: ResourceInfo) async -> ParsedElements {
        guard !parsed.elements.isEmpty else {
            return parsed
        }

        var result = parsed
        let range = resourceInfo.totalProgressionRange

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
