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
/// Extracts text content from PDF pages using lazy batch loading: pages are
/// read on demand as the caller advances through the iterator, rather than
/// loading the entire document upfront.
///
/// Each non-empty page is converted to a `TextContentElement` with a proper
/// locator for navigation and TTS.
///
/// If you want to start mid-resource, the `locator` must contain a `page=`
/// fragment, `position`, or a `progression` value.
///
/// If you want to start from the end of the resource, the `locator` must have
/// a `progression` of 1.0.
///
/// This ``ContentIterator`` requires the ``Publication`` to have a
/// ``PDFDocumentService``.
public class PDFResourceContentIterator: ContentIterator, Loggable {
    /// Factory for a `PDFResourceContentIterator`.
    public class Factory: ResourceContentIteratorFactory {
        /// Minimum number of non-empty content elements to load per batch.
        public let minimumElementsPerBatch: Int

        public init(minimumElementsPerBatch: Int = 10) {
            self.minimumElementsPerBatch = minimumElementsPerBatch
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
                            .flatMap { start -> ClosedRange<Double>? in
                                let end = positions.getOrNil(readingOrderIndex + 1)?
                                    .first?.locations.totalProgression ?? 1.0
                                guard start <= end else { return nil }
                                return start ... end
                            }
                    )
                },
                locator: locator,
                minimumElementsPerBatch: minimumElementsPerBatch
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

    private let openDocument: () async throws -> PDFDocument
    private let makeResourceInfo: () async -> ResourceInfo
    private let locator: Locator

    private let minimumElementsPerBatch: Int

    // MARK: - State

    /// All loaded content elements, growing in both directions as batches are
    /// fetched.
    private var elements: [TextContentElement] = []

    /// Range of PDF page indices (0-based) that have been processed so far.
    /// `nil` until the initial batch has been loaded.
    private var loadedPageRange: Range<Int>?

    /// The opened PDF document; retained for the lifetime of the iterator.
    private var document: (any PDFDocumentTextProviding)?

    /// Total number of pages in the document, fetched once on first access.
    private var pageCount: Int = 0

    /// Resource-level metadata fetched once on first access.
    private var resourceInfo: ResourceInfo?

    /// Index into `elements` of the element corresponding to the initial
    /// locator.
    private var startElementIndex: Int = 0

    /// Whether `loadInitialBatch()` has completed successfully.
    private var initialBatchLoaded: Bool = false

    /// Error captured during `loadInitialBatch()` to rethrow on subsequent
    /// calls.
    private var initialBatchError: Error?

    /// Current iteration position within `elements`. `nil` means not yet
    /// advanced.
    private var currentIndex: Int?

    init(
        openDocument: @escaping () async throws -> PDFDocument,
        resourceInfo: @escaping () async -> ResourceInfo,
        locator: Locator,
        minimumElementsPerBatch: Int = 10
    ) {
        self.openDocument = openDocument
        makeResourceInfo = resourceInfo
        self.locator = locator
        self.minimumElementsPerBatch = max(1, minimumElementsPerBatch)
    }

    // MARK: - ContentIterator

    public func next() async throws -> ContentElement? {
        if !initialBatchLoaded {
            try await loadInitialBatch()
        }

        let index = (currentIndex ?? (startElementIndex - 1)) + 1
        if index >= elements.count {
            guard let range = loadedPageRange, range.upperBound < pageCount else {
                return nil
            }
            let countBefore = elements.count
            try await loadBatchForward(from: range.upperBound)
            if elements.count == countBefore {
                // All remaining pages were empty.
                return nil
            }
        }

        guard index < elements.count else { return nil }
        currentIndex = index
        return elements[index]
    }

    public func previous() async throws -> ContentElement? {
        if !initialBatchLoaded {
            try await loadInitialBatch()
        }

        var index = (currentIndex ?? startElementIndex) - 1

        while index < 0 {
            guard let range = loadedPageRange, range.lowerBound > 0 else {
                return nil
            }
            let countBefore = elements.count
            try await loadBatchBackward()
            let added = elements.count - countBefore
            if added == 0 {
                return nil
            }
            // Prepending `added` elements shifts the target index forward.
            index += added
        }

        guard let content = elements.getOrNil(index) else { return nil }
        currentIndex = index
        return content
    }

    // MARK: - Initial Load

    private func loadInitialBatch() async throws {
        // Rethrow any previously captured error.
        if let error = initialBatchError {
            throw error
        }

        do {
            let info = await makeResourceInfo()
            resourceInfo = info

            let doc = try await openDocument()
            guard let textDoc = doc as? PDFDocumentTextProviding else {
                log(.warning, "The PDF document does not support text extraction; no content elements will be produced.")
                initialBatchLoaded = true
                return
            }

            document = textDoc
            pageCount = try await textDoc.pageCount()

            guard pageCount > 0 else {
                initialBatchLoaded = true
                return
            }

            let startPage = computeStartPage(positionOffset: info.positionOffset)
            try await loadBatchForward(from: startPage)
            startElementIndex = findStartElementIndex(for: startPage)

            initialBatchLoaded = true
        } catch {
            initialBatchError = error
            throw error
        }
    }

    /// Computes the 0-based page index to start loading from, derived directly
    /// from the locator without scanning any page text.
    private func computeStartPage(positionOffset: Int) -> Int {
        if let page = locator.locations.page {
            return max(0, min(page - 1, pageCount - 1))
        } else if let position = locator.locations.position {
            return max(0, position - positionOffset - 1)
        } else if locator.locations.progression == 1.0 {
            return pageCount - 1
        } else if let progression = locator.locations.progression, progression > 0 {
            return min(Int(progression * Double(pageCount)), pageCount - 1)
        } else {
            return 0
        }
    }

    /// Returns the index in `elements` of the element that best matches the
    /// start page, falling back to 0.
    private func findStartElementIndex(for startPage: Int) -> Int {
        let pageNumber = startPage + 1
        if locator.locations.page != nil {
            return elements.firstIndex { $0.locator.locations.page == pageNumber } ?? 0
        } else if let position = locator.locations.position {
            return elements.firstIndex { $0.locator.locations.position == position } ?? 0
        } else {
            return elements.firstIndex { ($0.locator.locations.page ?? 0) >= pageNumber } ?? 0
        }
    }

    // MARK: - Batch Loading

    /// Loads PDF pages starting at `startPageIndex`, appending elements until
    /// `minimumElementsPerBatch` non-empty pages are found or the end of the
    /// document is reached.
    private func loadBatchForward(from startPageIndex: Int) async throws {
        guard let doc = document, let info = resourceInfo else { return }

        var newElements: [TextContentElement] = []
        var nextPageIndex = startPageIndex

        while nextPageIndex < pageCount, newElements.count < minimumElementsPerBatch {
            let pageIndex = nextPageIndex
            nextPageIndex += 1

            guard
                let pageText = try await doc.pageText(at: pageIndex),
                !pageText.isBlank
            else { continue }

            newElements.append(makeElement(pageIndex: pageIndex, pageText: pageText, resourceInfo: info))
        }

        elements.append(contentsOf: newElements)
        if let existingRange = loadedPageRange {
            loadedPageRange = existingRange.lowerBound ..< nextPageIndex
        } else {
            loadedPageRange = startPageIndex ..< nextPageIndex
        }
    }

    /// Loads PDF pages just before the current `loadedPageRange`, prepending
    /// elements until `minimumElementsPerBatch` non-empty pages are found or
    /// the beginning of the document is reached.
    ///
    /// After prepending, `currentIndex` and `startElementIndex` are shifted to
    /// keep them pointing at the same logical elements.
    private func loadBatchBackward() async throws {
        guard
            let doc = document,
            let range = loadedPageRange,
            range.lowerBound > 0,
            let info = resourceInfo
        else { return }

        var newElements: [TextContentElement] = []
        var pageIndex = range.lowerBound - 1
        var lowestProcessedIndex = range.lowerBound

        while pageIndex >= 0, newElements.count < minimumElementsPerBatch {
            lowestProcessedIndex = pageIndex
            if let pageText = try await doc.pageText(at: pageIndex),
               !pageText.isBlank
            {
                // Prepend to maintain reading order (lowest page index first).
                newElements.insert(
                    makeElement(pageIndex: pageIndex, pageText: pageText, resourceInfo: info),
                    at: 0
                )
            }
            pageIndex -= 1
        }

        loadedPageRange = lowestProcessedIndex ..< range.upperBound

        guard !newElements.isEmpty else { return }

        let addedCount = newElements.count
        elements.insert(contentsOf: newElements, at: 0)

        if let idx = currentIndex {
            currentIndex = idx + addedCount
        }
        startElementIndex += addedCount
    }

    // MARK: - Helpers

    private func makeElement(pageIndex: Int, pageText: String, resourceInfo: ResourceInfo) -> TextContentElement {
        let pageNumber = pageIndex + 1
        let pageProgression = pageCount > 0 ? Double(pageIndex) / Double(pageCount) : 0.0
        let totalProgression = resourceInfo.totalProgressionRange.map {
            $0.lowerBound + pageProgression * ($0.upperBound - $0.lowerBound)
        }

        let pageLocator = locator.copy(
            locations: {
                $0.fragments = ["page=\(pageNumber)"]
                $0.position = resourceInfo.positionOffset + pageNumber
                $0.progression = pageProgression
                $0.totalProgression = totalProgression
            },
            text: {
                $0 = Locator.Text(highlight: pageText)
            }
        )

        return TextContentElement(
            locator: pageLocator,
            role: .body,
            segments: [
                TextContentElement.Segment(locator: pageLocator, text: pageText),
            ]
        )
    }
}
