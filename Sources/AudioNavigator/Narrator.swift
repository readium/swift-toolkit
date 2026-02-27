//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Narrates a homogeneous batch of ``PlaybackItem``s whose content type it
/// supports.
///
/// The ``AudioNavigator`` pulls items from a ``PlaybackCursor``, groups
/// consecutive items of the same content type into a batch, and delegates each
/// batch to the appropriate `Narrator`. Only one narrator is active at a time.
@MainActor
public protocol Narrator: AnyObject {
    /// Delegate that receives narration events.
    var delegate: (any NarratorDelegate)? { get set }

    /// Starts narrating with `item` as the first item, then pulls subsequent
    /// items from the delegate.
    ///
    /// The narrator fires ``NarratorDelegate/narrator(_:didActivateItem:)`` as
    /// each item becomes the active one, then
    /// ``NarratorDelegate/narratorDidFinish(_:)`` after the last item.
    func play(from item: PlaybackItem)

    /// Pauses narration. Has no effect when already paused or idle.
    func pause()

    /// Resumes paused narration. Has no effect when not paused.
    func resume()

    /// Stops narration and discards any buffered items.
    func stop()
}

/// Receives narration events from a ``Narrator``.
@MainActor
public protocol NarratorDelegate: AnyObject {
    /// Called by the narrator to request the next item.
    ///
    /// The navigator advances the cursor and returns the next compatible item,
    /// or `nil` when the sequence ends or the next item is incompatible with
    /// this narrator (in which case the navigator holds it as `pendingItem`
    /// for future narrator-switching).
    func narrator(_ narrator: any Narrator, nextItemAfter item: PlaybackItem?) async -> PlaybackItem?

    /// Called when `item` becomes the actively narrated item within the current
    /// batch, including when the first item in the batch starts.
    func narrator(_ narrator: any Narrator, didActivateItem item: PlaybackItem)

    /// Called when the narrator finishes all items in the batch.
    ///
    /// The ``AudioNavigator`` responds by pulling the next batch from the
    /// cursor and dispatching it to the appropriate narrator.
    func narratorDidFinish(_ narrator: any Narrator)

    /// Called when an unrecoverable error occurs.
    ///
    /// The narrator transitions to an idle state. The ``AudioNavigator`` may
    /// choose to skip the batch and continue, or propagate the error.
    func narrator(_ narrator: any Narrator, didFailWithError error: Error)
}
