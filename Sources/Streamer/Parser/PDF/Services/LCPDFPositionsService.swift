//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

final class LCPDFPositionsService: PositionsService, PDFPublicationService, Loggable {
    private let readingOrder: [Link]
    private let fetcher: Fetcher
    var pdfFactory: PDFDocumentFactory

    init(readingOrder: [Link], fetcher: Fetcher, pdfFactory: PDFDocumentFactory) {
        self.readingOrder = readingOrder
        self.fetcher = fetcher
        self.pdfFactory = pdfFactory
    }

    lazy var positionsByReadingOrder: [[Locator]] = {
        // Calculates the page count of each resource from the reading order.
        let resources = readingOrder.map { link -> (Int, Link) in
            let resource = fetcher.get(link)
            guard let document = try? pdfFactory.open(resource: resource, password: nil) else {
                log(.warning, "Can't get the number of pages from PDF document at \(link)")
                return (0, link)
            }
            return (document.pageCount, link)
        }

        let totalPageCount = resources.reduce(0) { count, current in count + current.0 }

        var lastPositionOfPreviousResource = 0
        return resources.map { pageCount, link -> [Locator] in
            guard pageCount > 0 else {
                return []
            }
            let positionList = makePositionList(of: link, pageCount: pageCount, totalPageCount: totalPageCount, startPosition: lastPositionOfPreviousResource)
            lastPositionOfPreviousResource += pageCount
            return positionList
        }
    }()

    private func makePositionList(of link: Link, pageCount: Int, totalPageCount: Int, startPosition: Int = 0) -> [Locator] {
        assert(pageCount > 0, "Invalid PDF page count")
        assert(totalPageCount > 0, "Invalid PDF total page count")

        return (1 ... pageCount).map { position in
            let progression = Double(position - 1) / Double(pageCount)
            let totalProgression = Double(startPosition + position - 1) / Double(totalPageCount)
            return Locator(
                href: link.href,
                type: link.type ?? MediaType.pdf.string,
                locations: .init(
                    fragments: ["page=\(position)"],
                    progression: progression,
                    totalProgression: totalProgression,
                    position: startPosition + position
                )
            )
        }
    }

    static func makeFactory(pdfFactory: PDFDocumentFactory) -> (PublicationServiceContext) -> LCPDFPositionsService? {
        { context in
            LCPDFPositionsService(
                readingOrder: context.manifest.readingOrder,
                fetcher: context.fetcher,
                pdfFactory: pdfFactory
            )
        }
    }
}
