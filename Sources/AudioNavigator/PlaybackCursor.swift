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
@MainActor
public protocol PlaybackCursor: AnyObject {
    /// Returns the next item in the sequence, or `nil` at the end.
    func next() async -> PlaybackItem?

    /// Returns the previous item in the sequence, or `nil` at the beginning.
    func previous() async -> PlaybackItem?

    /// Repositions the cursor to the nearest item at or after the given
    /// ``reference``.
    ///
    /// - Returns: Whether the reference could be resolved.
    @discardableResult
    func seek(to reference: any Reference) async -> Bool
}
