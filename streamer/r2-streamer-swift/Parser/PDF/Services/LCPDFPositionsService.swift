//
//  LCPDFPositionsService.swift
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

final class LCPDFPositionsService: PositionsService, Loggable {

    private let readingOrder: [Link]
    private let fetcher: R2Shared.Fetcher
    private let parserType: PDFFileParser.Type

    init(readingOrder: [Link], fetcher: R2Shared.Fetcher, parserType: PDFFileParser.Type) {
        self.readingOrder = readingOrder
        self.fetcher = fetcher
        self.parserType = parserType
    }
    
    lazy var positionsByReadingOrder: [[Locator]] = {
        // Calculates the page count of each resource from the reading order.
        let resources = readingOrder.map { link -> (Int, Link) in
            let resource = fetcher.get(link)
            guard
                // FIXME: We should be able to use the stream directly here instead of reading it fully into a Data object, but somehow it fails with random access in CBCDRMInputStream.
                let data = try? resource.read().get(),
                let parser = try? parserType.init(stream: DataInputStream(data: data)),
                let pageCount = try? parser.parseNumberOfPages() else
            {
                log(.warning, "Can't get the number of pages from PDF document at \(link)")
                return (0, link)
            }
            return (pageCount, link)
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
        
        return (1...pageCount).map { position in
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
    
    static func create(parserType: PDFFileParser.Type) -> (PublicationServiceContext) -> LCPDFPositionsService? {
        return { context in
            LCPDFPositionsService(
                readingOrder: context.manifest.readingOrder,
                fetcher: context.fetcher,
                parserType: parserType
            )
        }
    }
    
}
