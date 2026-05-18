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
                            .flatMap { start -> ClosedRange<Double>? in
                                let end = positions.getOrNil(readingOrderIndex + 1)?
                                    .first?.locations.totalProgression ?? 1.0
                                guard start <= end else { return nil }
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

    private let openDocument: () async throws -> PDFDocument
    private let makeResourceInfo: () async -> ResourceInfo
    private let locator: Locator

    /// The opened PDF document; retained for the lifetime of the iterator.
    private var document: (any PDFDocumentTextProviding)?

    /// Total number of pages in the document.
    private var pageCount: Int = 0

    /// Resource-level metadata fetched once on first access.
    private var resourceInfo: ResourceInfo?

    /// The page index (0-based) to start iteration from, derived from the
    /// locator.
    private var startPageIndex: Int = 0

    /// Whether initialization has completed.
    private var initialized: Bool = false

    /// Current page index (0-based). `nil` means iteration hasn't started yet.
    private var currentPageIndex: Int?

    init(
        openDocument: @escaping () async throws -> PDFDocument,
        resourceInfo: @escaping () async -> ResourceInfo,
        locator: Locator
    ) {
        self.openDocument = openDocument
        makeResourceInfo = resourceInfo
        self.locator = locator
    }

    // MARK: - ContentIterator

    public func next() async throws -> ContentElement? {
        try await initializeIfNeeded()

        var pageIndex = (currentPageIndex ?? (startPageIndex - 1)) + 1

        while pageIndex < pageCount {
            if let element = try await elementForPage(at: pageIndex) {
                currentPageIndex = pageIndex
                return element
            }
            pageIndex += 1
        }

        return nil
    }

    public func previous() async throws -> ContentElement? {
        try await initializeIfNeeded()

        var pageIndex = (currentPageIndex ?? startPageIndex) - 1

        while pageIndex >= 0 {
            if let element = try await elementForPage(at: pageIndex) {
                currentPageIndex = pageIndex
                return element
            }
            pageIndex -= 1
        }

        return nil
    }

    // MARK: - Initialization

    private func initializeIfNeeded() async throws {
        guard !initialized else { return }

        let info = await makeResourceInfo()
        resourceInfo = info

        let doc = try await openDocument()
        guard let textDoc = doc as? PDFDocumentTextProviding else {
            log(.warning, "The PDF document does not support text extraction; no content elements will be produced.")
            initialized = true
            return
        }

        document = textDoc
        pageCount = try await textDoc.pageCount()
        startPageIndex = computeStartPage(positionOffset: info.positionOffset)
        initialized = true
    }

    /// Computes the 0-based page index to start from, derived from the locator.
    private func computeStartPage(positionOffset: Int) -> Int {
        guard pageCount > 0 else { return 0 }

        if let page = locator.locations.page {
            return clampPageIndex(page - 1)
        } else if let position = locator.locations.position {
            return clampPageIndex(position - positionOffset - 1)
        } else if locator.locations.progression == 1.0 {
            return pageCount - 1
        } else if let progression = locator.locations.progression, progression > 0 {
            return clampPageIndex(Int(progression * Double(pageCount)))
        } else {
            return 0
        }
    }

    private func clampPageIndex(_ index: Int) -> Int {
        max(0, min(index, pageCount - 1))
    }

    // MARK: - Element Creation

    /// Returns a `TextContentElement` for the page at `pageIndex`, or `nil` if
    /// the page is empty.
    private func elementForPage(at pageIndex: Int) async throws -> TextContentElement? {
        guard let doc = document, let info = resourceInfo else { return nil }

        guard
            let pageText = try await doc.pageText(at: pageIndex),
            !pageText.isBlank
        else {
            return nil
        }

        return makeElement(pageIndex: pageIndex, pageText: pageText, resourceInfo: info)
    }

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
