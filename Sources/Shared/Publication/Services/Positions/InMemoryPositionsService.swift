//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A [PositionsService] holding the pre-computed position locators in memory.
public class InMemoryPositionsService : PositionsService {

    public private(set) var positionsByReadingOrder: [[Locator]]

    public init(positionsByReadingOrder: [[Locator]]) {
        self.positionsByReadingOrder = positionsByReadingOrder
    }

    public static func makeFactory(positionsByReadingOrder: [[Locator]]) -> (PublicationServiceContext) -> InMemoryPositionsService {
        { _ in
            InMemoryPositionsService(positionsByReadingOrder: positionsByReadingOrder)
        }
    }
}
