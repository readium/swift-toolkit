//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

final class PDFPositionsService: PositionsService {
    let positionsByReadingOrder: [[Locator]]

    init(link: Link, pageCount: Int, tableOfContents: [Link]) {
        assert(pageCount > 0, "Invalid PDF page count")
        // FIXME: Use the `tableOfContents` to generate the titles

        positionsByReadingOrder = [
            (1 ... pageCount).map { position in
                let progression = Double(position - 1) / Double(pageCount)
                return Locator(
                    href: link.href,
                    type: link.type ?? MediaType.pdf.string,
                    locations: .init(
                        fragments: ["page=\(position)"],
                        progression: progression,
                        totalProgression: progression,
                        position: position
                    )
                )
            },
        ]
    }

    static func makeFactory() -> (PublicationServiceContext) -> PDFPositionsService? {
        { context in
            guard
                let link = context.manifest.readingOrder.first,
                let pageCount = context.manifest.metadata.numberOfPages, pageCount > 0
            else {
                return nil
            }

            return PDFPositionsService(link: link, pageCount: pageCount, tableOfContents: context.manifest.tableOfContents)
        }
    }
}
