//
//  PerResourcePositionsService.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 01/06/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Simple `PositionsService` for a `Publication` which generates one position per `readingOrder`
/// resource.
public final class PerResourcePositionsService: PositionsService {
    
    private let readingOrder: [Link]
    
    /// Media type that will be used as a fallback if the `Link` doesn't specify any.
    private let fallbackMediaType: String
    
    init(readingOrder: [Link], fallbackMediaType: String) {
        self.readingOrder = readingOrder
        self.fallbackMediaType = fallbackMediaType
    }
    
    private lazy var pageCount: Int = readingOrder.count
    
    public lazy var positionsByReadingOrder: [[Locator]] = readingOrder.enumerated().map { (index, link) in
        [
            Locator(
                href: link.href,
                type: link.type ?? fallbackMediaType,
                title: link.title,
                locations: Locator.Locations(
                    totalProgression: Double(index) / Double(pageCount),
                    position: index + 1
                )
            )
        ]
    }
    
    public static func makeFactory(fallbackMediaType: String) -> (PublicationServiceContext) -> PerResourcePositionsService {
        return { context in
            PerResourcePositionsService(readingOrder: context.manifest.readingOrder, fallbackMediaType: fallbackMediaType)
        }
    }
    
}

