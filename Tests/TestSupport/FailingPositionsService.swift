//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Positions service failing to read the positions.
public struct FailingPositionsService: PositionsService {
    public init() {}

    public func positionsByReadingOrder() async -> ReadResult<[[Locator]]> {
        .failure(.decoding("Broken"))
    }
}
