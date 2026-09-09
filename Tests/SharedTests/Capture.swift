//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A reference-type wrapper that allows a value to be captured and mutated
/// inside a `@Sendable` closure.
///
/// Warning: Not thread-safe - only for sequential test code.
final class Capture<T>: @unchecked Sendable {
    var value: T

    init(_ value: T) {
        self.value = value
    }
}
