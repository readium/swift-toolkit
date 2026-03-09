//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@preconcurrency import ReadiumShared

/// Plays individual audio clips.
///
/// Implementations only need to play a bounded region of an audio file and
/// fire delegate callbacks as playback progresses.
@MainActor
public protocol AudioClipPlayer: AnyObject, Sendable {
    /// Delegate that receives playback events and requests from the player.
    var delegate: (any AudioClipPlayerDelegate)? { get set }

    // MARK: - Time

    /// Current playback position within the current clip, in seconds.
    var time: TimeInterval { get }

    /// Duration of the current clip in seconds, if known.
    var duration: TimeInterval? { get }

    /// Registers a block to be called at regular intervals while playing.
    ///
    /// - Parameters:
    ///   - interval: How often to fire the block, in seconds.
    ///   - block: Called on each tick; read `time` and `duration` from the
    ///     player directly (captured via `[weak self]` in the caller).
    /// - Returns: An opaque token that must be retained for as long as the
    ///   observation should remain active. Releasing the token cancels the
    ///   observer.
    func addPeriodicTimeObserver(
        forInterval interval: TimeInterval,
        using block: @escaping () -> Void
    ) -> Any

    // MARK: - Playback

    /// Current playback status.
    var status: AudioClipPlayerStatus { get }

    /// Plays the given clip immediately, replacing any current playback.
    ///
    /// The player plays from the first segment's start to the last segment's
    /// end (or the end of the file when `end` is `nil`), firing
    /// ``AudioClipPlayerDelegate/audioClipPlayer(_:willStartSegmentAt:in:)`` and
    /// ``AudioClipPlayerDelegate/audioClipPlayer(_:didFinishSegmentAt:in:)`` at each
    /// segment boundary.
    func play(_ clip: AudioClip)

    /// Pauses playback.
    func pause()

    /// Resumes paused playback.
    func resume()

    /// Stops playback and clears state.
    func stop()

    // MARK: - Seeking and Skipping

    /// Seeks to the given position within the current clip, in seconds.
    ///
    /// If the current clip has segments, and `time` falls outside of all
    /// segments, the position will be moved to the start of the next closest
    /// segment.
    ///
    /// Any segment observers between the current position and `time` are
    /// skipped without firing.
    ///
    /// If `time` is past the clip's end, the player behaves as if the clip
    /// finished naturally and fires
    /// ``AudioClipPlayerDelegate/audioClipPlayer(_:didFinishPlaying:)``.
    func seek(to time: TimeInterval)

    /// Skips to the next segment in the audio clip.
    ///
    /// - Returns: `true` if there is a next segment to skip to, `false`
    /// otherwise.
    func skipToNextSegment() -> Bool

    /// Skips to the previous segment in the audio clip.
    ///
    /// - Returns: `true` if there is a previous segment to skip to, `false`
    /// otherwise.
    func skipToPreviousSegment() -> Bool
}

/// Receives playback events from an ``AudioClipPlayer``.
@MainActor public protocol AudioClipPlayerDelegate: AnyObject {
    /// Returns a `Resource` providing access to the audio data for `link`.
    ///
    /// The player calls this to open a publication resource by link.
    func audioClipPlayer(_ player: any AudioClipPlayer, resourceFor link: Link) throws -> Resource

    /// Called when playback will begin playing the segment at the given `index`
    /// in the `clip`.
    func audioClipPlayer(_ player: any AudioClipPlayer, willStartSegmentAt index: Int, in clip: AudioClip)

    /// Called when playback reaches the end of the segment at the given `index`
    /// in the `clip`.
    func audioClipPlayer(_ player: any AudioClipPlayer, didFinishSegmentAt index: Int, in clip: AudioClip)

    /// Called when the player finishes playing a clip, either because it
    /// reached the last segment's end or because `seek(to:)` was called past that point.
    func audioClipPlayer(_ player: any AudioClipPlayer, didFinishPlaying clip: AudioClip)

    /// Called when the player's playback status changes.
    func audioClipPlayer(_ player: any AudioClipPlayer, didChangeStatus status: AudioClipPlayerStatus)

    /// Called when an unrecoverable error occurs while playing `clip`.
    /// The player transitions to `idle` status (as if `stop()` was called).
    func audioClipPlayer(_ player: any AudioClipPlayer, didFailPlaying clip: AudioClip, withError error: Error)
}

/// The playback status of an ``AudioClipPlayer``.
///
/// Transitions typically follow: ``idle`` → ``loading`` → ``playing``.
/// Rebuffering mid-playback moves from ``playing`` back to ``loading``.
/// An explicit ``AudioClipPlayer/pause()`` call moves to ``paused`` from any
/// non-idle state.
public enum AudioClipPlayerStatus: Hashable, Sendable {
    /// No clip is loaded. The player is waiting for a ``AudioClipPlayer/play(_:)``
    /// call.
    case idle

    /// The player intends to play, but the clip is loading or waiting for
    /// enough data to start or resume.
    case loading

    /// The player is actively playing audio.
    case playing

    /// Playback is paused. The player will resume from the current position
    /// when ``AudioClipPlayer/resume()`` is called.
    case paused
}
