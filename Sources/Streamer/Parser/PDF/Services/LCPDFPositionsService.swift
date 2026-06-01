//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumShared

/// Generates positions for an LCPDF publication by opening each PDF resource
/// to get its page count.
///
/// Requires the publication to have a ``PDFDocumentService``.
final class LCPDFPositionsService: PositionsService, Loggable, Sendable {
    private let cache: AsyncMemoizer<ReadResult<[[Locator]]>>

    init(publication: Weak<Publication>) {
        cache = AsyncMemoizer { [publication] in
            guard let publication = publication() else {
                return .failure(.unsupportedOperation(DebugError("The publication is deallocated")))
            }

            return await Self.makePositionList(of: publication)
        }
    }

    func positionsByReadingOrder() async -> ReadResult<[[Locator]]> {
        await cache()
    }

    private static func makePositionList(of publication: Publication) async -> ReadResult<[[Locator]]> {
        guard let pdfDocumentService = publication.pdfDocumentService else {
            return .failure(.unsupportedOperation(DebugError("PDFDocumentService is required to use the LCPDFPositionsService")))
        }
        // Calculates the page count of each resource from the reading order.
        let resources = await publication.readingOrder.asyncMap { link -> (Int, Link) in
            let href = link.url()
            guard
                let document = try? await pdfDocumentService.openDocument(at: href),
                let pageCount = try? await document.pageCount()
            else {
                LCPDFPositionsService.log(.warning, "Can't get the number of pages from PDF document at \(link)")
                return (0, link)
            }
            return (pageCount, link)
        }

        let totalPageCount = resources.reduce(0) { count, current in count + current.0 }

        var lastPositionOfPreviousResource = 0

        return .success(resources.map { pageCount, link -> [Locator] in
            guard pageCount > 0 else {
                return []
            }
            let positionList = makePositionList(of: link, pageCount: pageCount, totalPageCount: totalPageCount, startPosition: lastPositionOfPreviousResource)
            lastPositionOfPreviousResource += pageCount
            return positionList
        })
    }

    private static func makePositionList(of link: Link, pageCount: Int, totalPageCount: Int, startPosition: Int = 0) -> [Locator] {
        assert(pageCount > 0, "Invalid PDF page count")
        assert(totalPageCount > 0, "Invalid PDF total page count")

        return (1 ... pageCount).map { position in
            let progression = Double(position - 1) / Double(pageCount)
            let totalProgression = Double(startPosition + position - 1) / Double(totalPageCount)
            return Locator(
                href: link.url(),
                mediaType: link.mediaType ?? .pdf,
                locations: .init(
                    fragments: ["page=\(position)"],
                    progression: progression,
                    totalProgression: totalProgression,
                    position: startPosition + position
                )
            )
        }
    }

    static func makeFactory() -> @Sendable (PublicationServiceContext) -> LCPDFPositionsService? {
        { context in
            LCPDFPositionsService(publication: context.publication)
        }
    }
}
