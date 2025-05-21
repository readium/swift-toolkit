//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

final class PDFPositionsService: PositionsService {
    init(link: Link, pageCount: Int, tableOfContents: [Link]) {
        assert(pageCount > 0, "Invalid PDF page count")
        // FIXME: Use the `tableOfContents` to generate the titles

        _positionsByReadingOrder = [
            (1 ... pageCount).map { position in
                let progression = Double(position - 1) / Double(pageCount)
                return Locator(
                    href: link.url(),
                    mediaType: link.mediaType ?? .pdf,
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

    private let _positionsByReadingOrder: [[Locator]]

    func positionsByReadingOrder() async -> ReadResult<[[Locator]]> {
        .success(_positionsByReadingOrder)
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
