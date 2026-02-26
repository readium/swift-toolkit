//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A wrapper to force a value to be `Sendable`.
///
/// **Warning**: Use this wrapper only if you are sure that the value is thread-safe.
public struct UncheckedSendable<T>: @unchecked Sendable {
    public let value: T

    public init(_ value: T) {
        self.value = value
    }
}
