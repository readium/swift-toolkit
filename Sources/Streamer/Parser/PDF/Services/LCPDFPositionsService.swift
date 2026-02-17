//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumShared

final class LCPDFPositionsService: PositionsService, PDFPublicationService, Loggable, @unchecked Sendable {
    private let readingOrder: [Link]
    private let container: Container
    private let positionsByReadingOrderTask: Task<ReadResult<[[Locator]]>, Never>

    var pdfFactory: PDFDocumentFactory

    init(readingOrder: [Link], container: Container, pdfFactory: PDFDocumentFactory) {
        self.readingOrder = readingOrder
        self.container = container
        self.pdfFactory = pdfFactory

        struct Captures: Sendable {
            let readingOrder: [Link]
            let container: Container
            let pdfFactory: PDFDocumentFactory
        }
        let captures = Captures(readingOrder: readingOrder, container: container, pdfFactory: pdfFactory)

        positionsByReadingOrderTask = Task {
            let readingOrder = captures.readingOrder
            let container = captures.container
            let pdfFactory = captures.pdfFactory

            // Calculates the page count of each resource from the reading order.
            let resources = await readingOrder.asyncMap { link -> (Int, Link) in
                let href = link.url()
                guard
                    let resource = container[href],
                    let document = try? await pdfFactory.open(resource: resource, at: href, password: nil),
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
                let positionList = LCPDFPositionsService.makePositionList(of: link, pageCount: pageCount, totalPageCount: totalPageCount, startPosition: lastPositionOfPreviousResource)
                lastPositionOfPreviousResource += pageCount
                return positionList
            })
        }
    }

    func positionsByReadingOrder() async -> ReadResult<[[Locator]]> {
        await positionsByReadingOrderTask.value
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

    static func makeFactory(pdfFactory: PDFDocumentFactory) -> @Sendable (PublicationServiceContext) -> LCPDFPositionsService? {
        struct Captures: Sendable {
            let pdfFactory: PDFDocumentFactory
        }
        let captures = Captures(pdfFactory: pdfFactory)

        return { context in
            LCPDFPositionsService(
                readingOrder: context.manifest.readingOrder,
                container: context.container,
                pdfFactory: captures.pdfFactory
            )
        }
    }
}
