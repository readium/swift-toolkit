//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Narrates a homogeneous batch of ``PlaybackItem``s whose content type it
/// supports.
@MainActor public protocol Narrator: AnyObject, Sendable {
    /// Delegate that receives narration events.
    var delegate: (any NarratorDelegate)? { get set }

    /// Current narrator status.
    var status: NarratorStatus { get }

    /// Returns whether this narrator can handle `item`.
    ///
    /// The ``AudioNavigator`` calls this to decide when to end the current
    /// batch and switch narrators.
    func supports(_ item: PlaybackItem) -> Bool

    // MARK: - Time

    /// Registers a block to be called at regular intervals while playing.
    ///
    /// - Parameters:
    ///   - interval: How often to fire the block, in seconds.
    ///   - block: Called on each tick; read `time(in:)` and `duration(of:)`
    ///     from the narrator directly (captured via `[weak self]` in the caller).
    /// - Returns: An opaque token that must be retained for as long as the
    ///   observation should remain active. Releasing the token cancels the
    ///   observer.
    func addPeriodicTimeObserver(
        forInterval interval: TimeInterval,
        using block: @escaping () -> Void
    ) -> Any

    /// Returns the current playback position within `scope`, in seconds, or
    /// `nil` if no item is currently active or the time for the requested scope
    /// cannot be determined.
    func time(in scope: TimeScope) -> TimeInterval?

    /// Returns the total duration of `scope` in seconds, or `nil` if it is not
    /// yet known, or the duration for the requested scope cannot be determined.
    func duration(of scope: TimeScope) -> TimeInterval?

    // MARK: - Playback Control

    /// Starts narrating with `item` as the first item, then pulls subsequent
    /// items from the delegate.
    ///
    /// The narrator fires ``NarratorDelegate/narrator(_:willPlayItem:)`` as
    /// each item becomes the active one, then
    /// ``NarratorDelegate/narratorDidFinish(_:)`` after the last item.
    func play(from item: PlaybackItem)

    /// Pauses narration. Has no effect when already paused or idle.
    func pause()

    /// Resumes paused narration. Has no effect when not paused.
    func resume()

    /// Stops narration and discards any prepared items.
    func stop()

    // MARK: - Navigation

    /// Attempts to activate the next item within the current batch.
    ///
    /// - Returns: `true` if successful, `false` when already at the last
    /// item.
    @discardableResult
    func goForward() -> Bool

    /// Attempts to activate the previous item within the current batch.
    ///
    /// Returns `true` if successful. Returns `false` when already at the first
    /// item.
    @discardableResult
    func goBackward() -> Bool
}

/// Receives narration events from a ``Narrator``.
@MainActor
public protocol NarratorDelegate: AnyObject {
    /// Called when the narrator's status changes.
    func narrator(_ narrator: any Narrator, didChangeStatus status: NarratorStatus)

    /// Called by the narrator to request the next item to narrate.
    ///
    /// The navigator advances the cursor and returns the next compatible item,
    /// or `nil` when the sequence ends or the next item belongs to a different
    /// narrator type, signalling the narrator to finish.
    func narrator(_ narrator: any Narrator, nextItemAfter item: PlaybackItem) async -> PlaybackItem?

    /// Called just before `item` begins playing.
    func narrator(_ narrator: any Narrator, willPlayItem item: PlaybackItem)

    /// Called when the narrator finishes all items.
    func narratorDidFinish(_ narrator: any Narrator)

    /// Called when an unrecoverable error occurs.
    ///
    /// The narrator transitions to an idle state.
    func narrator(_ narrator: any Narrator, didFailWithError error: Error)
}

public enum NarratorStatus: Hashable, Sendable {
    /// No playback item is loaded. The narrator is waiting for a `play(from:)`.
    /// call.
    case idle

    /// The narrator intends to play an item, but it is loading or waiting for
    /// enough data to start or resume.
    case loading

    /// The narrator is actively playing an item.
    case playing

    /// Narration is paused. The narrator will resume from the current item
    /// when `resume()` is called.
    case paused
}
