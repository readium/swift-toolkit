//
//  EPUBPositionsService.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 31/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

/// Positions Service for an EPUB from its `readingOrder` and `fetcher`.
///
/// The `presentation` is used to apply different calculation strategy if the resource has a
/// reflowable or fixed layout.
///
/// https://github.com/readium/architecture/blob/master/models/locators/best-practices/format.md#epub
/// https://github.com/readium/architecture/issues/101
///
final class EPUBPositionsService: PositionsService {
    
    private let readingOrder: [Link]
    private let presentation: Presentation
    private let fetcher: Fetcher
    
    /// Length in bytes of a position in a reflowable resource. This is used to split a single
    /// reflowable resource into several positions.
    private let reflowablePositionLength: Int
    
    init(readingOrder: [Link], presentation: Presentation, fetcher: Fetcher, reflowablePositionLength: Int) {
        self.readingOrder = readingOrder
        self.fetcher = fetcher
        self.presentation = presentation
        self.reflowablePositionLength = reflowablePositionLength
    }
    
    lazy var positionsByReadingOrder: [[Locator]] = {
        var lastPositionOfPreviousResource = 0
        var positions = readingOrder.map { link -> [Locator] in
            let (lastPosition, positions): (Int, [Locator]) = {
                if presentation.layout(of: link) == .fixed {
                    return makePositions(ofFixedResource: link, from: lastPositionOfPreviousResource)
                } else {
                    return makePositions(ofReflowableResource: link, from: lastPositionOfPreviousResource)
                }
            }()
            lastPositionOfPreviousResource = lastPosition
            return positions
        }
        
        // Calculates totalProgression
        let totalPageCount = positions.map { $0.count }.reduce(0, +)
        if totalPageCount > 0 {
            positions = positions.map { locators in
                locators.map { locator in
                    locator.copy(locations: {
                        if let position = $0.position {
                            $0.totalProgression = Double(position - 1) / Double(totalPageCount)
                        }
                    })
                }
            }
        }
        
        return positions
    }()
    
    private func makePositions(ofFixedResource link: Link, from startPosition: Int) -> (Int, [Locator]) {
        let position = startPosition + 1
        let positions = [
            makeLocator(
                for: link,
                progression: 0,
                position: position
            )
        ]
        return (position, positions)
    }
    
    private func makePositions(ofReflowableResource link: Link, from startPosition: Int) -> (Int, [Locator]) {
        // If the resource is encrypted, we use the originalLength declared in encryption.xml instead of the ZIP entry length
        let length = link.properties.encryption?.originalLength
            ?? Int((try? fetcher.get(link).length.get()) ?? 0)

        // Arbitrary byte length of a single page in a resource.
        let pageLength = reflowablePositionLength
        let pageCount = max(1, Int(ceil((Double(length) / Double(pageLength)))))
        
        let positions = (1...pageCount).map { position in
            makeLocator(
                for: link,
                progression: Double(position - 1) / Double(pageCount),
                position: startPosition + position
            )
        }
        return (startPosition + pageCount, positions)
    }
    
    private func makeLocator(for link: Link, progression: Double, position: Int) -> Locator {
        return Locator(
            href: link.href,
            type: link.type ?? MediaType.html.string,
            title: link.title,
            locations: .init(
                progression: progression,
                position: position
            )
        )
    }

    static func makeFactory(reflowablePositionLength: Int = 1024) -> (PublicationServiceContext) -> EPUBPositionsService? {
        return { context in
            EPUBPositionsService(
                readingOrder: context.manifest.readingOrder,
                presentation: context.manifest.metadata.presentation,
                fetcher: context.fetcher,
                reflowablePositionLength: reflowablePositionLength
            )
        }
    }
    
}
