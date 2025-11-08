//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumShared
#if canImport(PDFKit)
    import PDFKit
#endif

/// Iterates a PDF `resource`, starting from the given `locator`.
///
/// Extracts text content from PDF pages using PDFKit. Each page is converted to a
/// `TextContentElement` with proper locators for navigation and TTS.
///
/// If you want to start mid-resource, the `locator` must contain a `position` key
/// in its `Locator.Locations` object indicating the page number.
///
/// If you want to start from the end of the resource, the `locator` must have
/// a `progression` of 1.0.
///
/// **Note**: This implementation requires PDFKit and is only available on platforms
/// that support it (iOS, macOS, Mac Catalyst).
public class PDFResourceContentIterator: ContentIterator {
    /// Factory for a `PDFResourceContentIterator`.
    ///
    /// **Note**: Requires PDFKit for text extraction. Returns `nil` on platforms
    /// where PDFKit is not available.
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
            #if canImport(PDFKit)
                guard publication.readingOrder.getOrNil(readingOrderIndex)?.mediaType == .pdf else {
                    return nil
                }

                return PDFResourceContentIterator(
                    resource: resource,
                    pdfFactory: pdfFactory,
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
            #else
                return nil
            #endif
        }
    }

    #if canImport(PDFKit)
        private let resource: Resource
        private let pdfFactory: PDFDocumentFactory
        private let locator: Locator
        private let beforeMaxLength: Int = 50
        private let totalProgressionRange: Task<ClosedRange<Double>?, Never>
        // Keep a strong reference to the PDF document to prevent deallocation during text extraction
        private var pdfDocument: PDFKit.PDFDocument?

        public init(
            resource: Resource,
            pdfFactory: PDFDocumentFactory,
            totalProgressionRange: @escaping () async -> ClosedRange<Double>?,
            locator: Locator
        ) {
            self.resource = resource
            self.pdfFactory = pdfFactory
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
            await elementsTask.value
        }

        private lazy var elementsTask = Task {
            let parsed = await extractPDFText(
                resource: resource,
                pdfFactory: pdfFactory,
                locator: locator,
                beforeMaxLength: beforeMaxLength
            )
            return await adjustProgressions(of: parsed)
        }

        /// Extracts text content from PDF pages and converts to ContentElements.
        ///
        /// This is an async operation because it needs to read the PDF resource
        /// and extract text from pages using PDFKit.
        private func extractPDFText(
            resource: Resource,
            pdfFactory: PDFDocumentFactory,
            locator: Locator,
            beforeMaxLength: Int
        ) async -> ParsedElements {
            do {
                // For text extraction, we need PDFKit.PDFDocument directly
                // Try to get it from the resource data, since PDFKit requires the full document in memory
                let result = await resource.read()
                let data: Data
                switch result {
                case let .success(resultData):
                    data = resultData
                case .failure:
                    return ParsedElements(elements: [], startIndex: 0)
                }

                // Create a copy of the data to ensure it's retained
                let dataCopy = Data(data)
                guard let pdfDocument = PDFKit.PDFDocument(data: dataCopy) else {
                    return ParsedElements(elements: [], startIndex: 0)
                }

                // Store a strong reference to prevent deallocation
                self.pdfDocument = pdfDocument

                let pageCount = pdfDocument.pageCount
                guard pageCount > 0 else {
                    return ParsedElements(elements: [], startIndex: 0)
                }

                // Determine starting page from locator
                let startPageIndex: Int = {
                    if let position = locator.locations.position {
                        // Page numbers are typically 1-based in PDFs, but PDFKit uses 0-based indices
                        return max(0, min(position - 1, pageCount - 1))
                    } else if let progression = locator.locations.progression {
                        // Calculate page from progression (0.0 to 1.0)
                        return Int(progression * Double(pageCount))
                    } else {
                        return 0
                    }
                }()

                // Extract text from each page
                var elements: [ContentElement] = []
                var wholeText = ""

                for pageIndex in 0 ..< pageCount {
                    guard let page = pdfDocument.page(at: pageIndex) else {
                        continue
                    }

                    // Extract text from page
                    guard let pageText = page.string, !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        // Skip empty pages
                        continue
                    }

                    // Create locator for this page
                    // Position in PDF locators is 1-based (page number)
                    let pageNumber = pageIndex + 1
                    let pageProgression = Double(pageIndex) / Double(pageCount)

                    let pageLocator = locator.copy(
                        locations: {
                            $0.position = pageNumber
                            $0.progression = pageProgression
                            $0.otherLocations = [
                                "pageNumber": pageNumber,
                            ]
                        },
                        text: {
                            // Include context for locator text
                            let beforeText = String(wholeText.suffix(beforeMaxLength))
                            $0 = Locator.Text(
                                after: nil,
                                before: beforeText.isEmpty ? nil : beforeText,
                                highlight: pageText
                            )
                        }
                    )

                    // Create TextContentElement for this page
                    // Split page text into paragraphs for better TTS granularity
                    // PDF text extraction doesn't always preserve paragraph separators,
                    // so we try multiple approaches:
                    var paragraphs = pageText.components(separatedBy: "\n\n")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    // If no double newlines found, try single newlines
                    // First, split by single newlines WITHOUT filtering empty strings
                    // so we can detect paragraph breaks (empty lines)
                    if paragraphs.count <= 1 {
                        let allLines = pageText.components(separatedBy: "\n")

                        // Group consecutive non-empty lines into paragraphs
                        // A paragraph break occurs when we encounter an empty line
                        var grouped: [String] = []
                        var currentGroup: [String] = []

                        for line in allLines {
                            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty {
                                // Empty line = paragraph break
                                if !currentGroup.isEmpty {
                                    grouped.append(currentGroup.joined(separator: " "))
                                    currentGroup = []
                                }
                            } else {
                                currentGroup.append(trimmed)
                            }
                        }

                        // Add the last group if any
                        if !currentGroup.isEmpty {
                            grouped.append(currentGroup.joined(separator: " "))
                        }

                        if grouped.count > 1 {
                            paragraphs = grouped
                        } else {
                            // If no paragraph breaks found, use sentence-based splitting as fallback
                            // Split by sentence endings and group sentences
                            let sentences = pageText.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }

                            if sentences.count > 3 {
                                // Group every 3-5 sentences into a paragraph for better granularity
                                let sentencesPerParagraph = max(3, min(5, max(3, sentences.count / 15 + 1)))
                                var sentenceGroups: [String] = []
                                var currentSentenceGroup: [String] = []

                                for sentence in sentences {
                                    currentSentenceGroup.append(sentence)
                                    if currentSentenceGroup.count >= sentencesPerParagraph {
                                        sentenceGroups.append(currentSentenceGroup.joined(separator: ". ") + ".")
                                        currentSentenceGroup = []
                                    }
                                }

                                if !currentSentenceGroup.isEmpty {
                                    sentenceGroups.append(currentSentenceGroup.joined(separator: ". ") + ".")
                                }

                                if sentenceGroups.count > 1 {
                                    paragraphs = sentenceGroups
                                }
                            }
                        }
                    }

                    if paragraphs.isEmpty {
                        // Single element for the entire page
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
                    } else {
                        // Create element per paragraph for better granularity
                        for (paraIndex, paragraph) in paragraphs.enumerated() {
                            let paraProgression = pageProgression + (Double(paraIndex) / Double(paragraphs.count)) / Double(pageCount)
                            let paraLocator = pageLocator.copy(
                                locations: {
                                    $0.progression = paraProgression
                                    $0.otherLocations = [
                                        "pageNumber": pageNumber,
                                        "paragraphIndex": paraIndex,
                                    ]
                                },
                                text: {
                                    let beforeText = String(wholeText.suffix(beforeMaxLength))
                                    $0 = Locator.Text(
                                        after: nil,
                                        before: beforeText.isEmpty ? nil : beforeText,
                                        highlight: paragraph
                                    )
                                }
                            )

                            elements.append(TextContentElement(
                                locator: paraLocator,
                                role: .body,
                                segments: [
                                    TextContentElement.Segment(
                                        locator: paraLocator,
                                        text: paragraph
                                    ),
                                ]
                            ))
                        }
                    }

                    wholeText += pageText + "\n\n"
                }

                // Calculate start index based on locator
                let startIndex: Int = {
                    // Priority 1: Match by position AND paragraphIndex (most precise)
                    if let position = locator.locations.position,
                       let savedParaIndex = locator.locations.otherLocations["paragraphIndex"] as? Int
                    {
                        // First try to find exact match by paragraphIndex
                        if let index = elements.firstIndex(where: { element in
                            element.locator.locations.position == position &&
                                element.locator.locations.otherLocations["paragraphIndex"] as? Int == savedParaIndex
                        }) {
                            return index
                        }
                        // Fallback: find first element on the same page
                        return elements.firstIndex { element in
                            element.locator.locations.position == position
                        } ?? 0
                    }

                    // Priority 2: Match by position only (page number)
                    if let position = locator.locations.position {
                        // Find all elements on this page
                        let pageElements = elements.enumerated().filter { _, element in
                            element.locator.locations.position == position
                        }

                        // If we have a saved progression and multiple elements on the page,
                        // try to find the closest match by progression
                        if pageElements.count > 1,
                           let savedProgression = locator.locations.progression,
                           savedProgression > 0, savedProgression < 1
                        {
                            if let closest = pageElements.min(by: { lhs, rhs in
                                let lhsProg = abs((lhs.element.locator.locations.progression ?? 0) - savedProgression)
                                let rhsProg = abs((rhs.element.locator.locations.progression ?? 0) - savedProgression)
                                return lhsProg < rhsProg
                            }) {
                                return closest.offset
                            }
                        }

                        // Fallback: use first element on the page
                        return pageElements.first?.offset ?? elements.firstIndex { element in
                            element.locator.locations.position == position
                        } ?? 0
                    } else if let progression = locator.locations.progression {
                        // Find element closest to the progression
                        if let closest = elements.enumerated().min(by: { lhs, rhs in
                            let lhsProg = abs((lhs.element.locator.locations.progression ?? 0) - progression)
                            let rhsProg = abs((rhs.element.locator.locations.progression ?? 0) - progression)
                            return lhsProg < rhsProg
                        }) {
                            return closest.offset
                        }
                        // Fallback to lastIndex method
                        return elements.lastIndex { element in
                            (element.locator.locations.progression ?? 0) < progression
                        } ?? 0
                    } else if locator.locations.progression == 1.0 {
                        return elements.count - 1
                    } else {
                        return 0
                    }
                }()

                return ParsedElements(elements: elements, startIndex: startIndex)
            } catch {
                return ParsedElements(elements: [], startIndex: 0)
            }
        }

        private func adjustProgressions(of elements: ParsedElements) async -> ParsedElements {
            let count = Double(elements.elements.count)
            guard count > 0 else {
                return elements
            }

            var elements = elements
            elements.elements = await elements.elements.enumerated().asyncMap { index, element in
                let progression = Double(index) / count
                return await element.copy(
                    progression: progression,
                    totalProgression: totalProgressionRange.value.map { range in
                        range.lowerBound + progression * (range.upperBound - range.lowerBound)
                    }
                )
            }

            // Update the `startIndex` if a particular progression was requested.
            // But only if startIndex wasn't already calculated (i.e., it's 0 and we're using progression matching)
            if
                elements.startIndex == 0,
                locator.locations.position == nil,
                let progression = locator.locations.progression,
                progression > 0, progression < 1
            {
                elements.startIndex = elements.elements.lastIndex { element in
                    let elementProgression = element.locator.locations.progression ?? 0
                    return elementProgression < progression
                } ?? 0
            }

            return elements
        }

        /// Holds the result of parsing the PDF resource into a list of `ContentElement`.
        ///
        /// The `startIndex` will be calculated from the element matched by the
        /// base `locator`, if possible. Defaults to 0.
        private struct ParsedElements {
            var elements: [ContentElement] = []
            var startIndex: Int = 0
        }
    #else
        // Fallback for platforms without PDFKit
        public func previous() async throws -> ContentElement? { nil }
        public func next() async throws -> ContentElement? { nil }
    #endif
}

// MARK: - ContentElement Extension

private extension ContentElement {
    func copy(progression: Double?, totalProgression: Double?) async -> ContentElement {
        func update(_ locator: Locator) -> Locator {
            locator.copy(locations: {
                $0.progression = progression
                $0.totalProgression = totalProgression
            })
        }

        switch self {
        case var e as TextContentElement:
            e.locator = update(e.locator)
            e.segments = e.segments.map { segment in
                var segment = segment
                segment.locator = update(segment.locator)
                return segment
            }
            return e

        case var e as AudioContentElement:
            e.locator = update(e.locator)
            return e

        case var e as ImageContentElement:
            e.locator = update(e.locator)
            return e

        case var e as VideoContentElement:
            e.locator = update(e.locator)
            return e

        default:
            return self
        }
    }
}
