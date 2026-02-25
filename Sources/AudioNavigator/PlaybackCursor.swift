//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A lazy, bidirectional iterator over a playback sequence.
///
/// `next()` returns the item to the right of the cursor and advances it
/// rightward. `previous()` retreats the cursor leftward and returns the
/// item now to the right. This means alternating `next()` / `previous()`
/// always re-returns the same item.
public protocol PlaybackCursor: Sendable {
    /// Returns the next item in the sequence, or `nil` at the end.
    mutating func next() async -> PlaybackItem?

    /// Returns the previous item in the sequence, or `nil` at the beginning.
    mutating func previous() async -> PlaybackItem?

    /// Repositions the cursor to the nearest item at or after the given
    /// ``reference``.
    ///
    /// - Returns: Whether the reference could be resolved.
    @discardableResult
    mutating func seek(to reference: any Reference) async -> Bool
}
