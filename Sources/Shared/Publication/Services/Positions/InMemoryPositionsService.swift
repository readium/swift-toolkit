//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A ``PositionsService`` holding the pre-computed position locators in memory.
public class InMemoryPositionsService: PositionsService {
    private let _positions: [[Locator]]

    public init(positionsByReadingOrder: [[Locator]]) {
        _positions = positionsByReadingOrder
    }

    public func positionsByReadingOrder() async -> ReadResult<[[Locator]]> {
        .success(_positions)
    }

    public static func makeFactory(positionsByReadingOrder: [[Locator]]) -> (PublicationServiceContext) -> InMemoryPositionsService {
        { _ in
            InMemoryPositionsService(positionsByReadingOrder: positionsByReadingOrder)
        }
    }
}
