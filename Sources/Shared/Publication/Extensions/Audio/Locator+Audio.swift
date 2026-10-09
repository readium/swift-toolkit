//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Audio extensions for `Locator.Locations`.
public extension Locator.Locations {
    /// The temporal dimension of the media fragments, if there is any.
    ///
    /// When several fragments have a valid temporal dimension, the last one
    /// wins.
    ///
    /// - https://www.w3.org/TR/media-frags/#naming-time
    var temporal: TemporalSelector? {
        fragments
            .reversed()
            .lazy
            .compactMap(\.temporalSelector)
            .first
    }

    @available(*, unavailable, message: "Use `TemporalSelector` instead.")
    enum TimeFragment {}

    @available(*, unavailable, message: "Use `temporal` instead, e.g. `temporal?.start` to get the beginning.")
    var time: TimeFragment? {
        fatalError()
    }
}
