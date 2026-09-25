//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Throttles the given `block` so that it is executed in `duration` seconds, ignoring additional
/// calls until then.
@available(*, unavailable, message: "This utility was an internal helper that leaked through ReadiumShared.")
@MainActor
public func throttle(
    duration: TimeInterval = 0,
    _ block: @escaping @Sendable @MainActor () -> Void
) -> @Sendable @MainActor () -> Void {
    fatalError()
}
