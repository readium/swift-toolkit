//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension Sequence {
    /// Asynchronous variant of `map`.
    @inlinable func asyncMap<NewElement>(
        _ transform: (Element) async throws -> NewElement
    ) async rethrows -> [NewElement] {
        var result: [NewElement] = []
        for element in self {
            try await result.append(transform(element))
        }
        return result
    }
}
