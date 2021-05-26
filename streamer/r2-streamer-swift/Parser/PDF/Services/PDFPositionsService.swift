//
//  PDFPositionsService.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 30/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

final class PDFPositionsService: PositionsService {
    
    let positionsByReadingOrder: [[Locator]]
    
    init(link: Link, pageCount: Int, tableOfContents: [Link]) {
        assert(pageCount > 0, "Invalid PDF page count")
        // FIXME: Use the `tableOfContents` to generate the titles

        positionsByReadingOrder = [
            (1...pageCount).map { position in
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
            }
        ]
    }
    
    static func makeFactory() -> (PublicationServiceContext) -> PDFPositionsService? {
        return { context in
            guard
                let link = context.manifest.readingOrder.first,
                let pageCount = context.manifest.metadata.numberOfPages, pageCount > 0 else
            {
                return nil
            }
    
            return PDFPositionsService(link: link, pageCount: pageCount, tableOfContents: context.manifest.tableOfContents)
        }
    }

}
