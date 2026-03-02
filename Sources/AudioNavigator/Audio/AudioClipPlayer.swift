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
    /// The player plays from `clip.start` to `clip.end` (or the end of the
    /// file when `end` is `nil`), firing
    /// ``AudioClipPlayerDelegate/audioClipPlayer(_:didReachMarker:)`` as each marker
    /// position is passed.
    func play(_ clip: AudioClip)

    /// Pauses playback.
    func pause()

    /// Resumes paused playback.
    func resume()

    /// Stops playback and clears any prepared audio clips.
    func stop()

    /// Seeks to the given position within the current clip, in seconds.
    ///
    /// Any markers between the current position and `time` are skipped without
    /// firing. If `time` is past the clip's `end`, the player behaves as if
    /// the clip finished naturally and fires
    /// ``AudioClipPlayerDelegate/audioClipPlayer(_:didFinishPlaying:)``.
    ///
    /// This may be called from within a
    /// ``AudioClipPlayerDelegate/audioClipPlayer(_:didReachMarker:)`` callback,
    /// for example to skip a gap to the start of the next playback item.
    func seek(to time: TimeInterval)

    // MARK: - Preparation

    /// Best-effort hint to start buffering a clip before it is needed.
    ///
    /// Called while the current clip is playing so the next clip's asset is
    /// ready when `play()` is called. Implementations that cannot benefit (e.g.
    /// local files that load instantly) may ignore this.
    ///
    /// It is always possible to call `play()` on an unprepared clip.
    func prepare(_ clip: AudioClip)
}

/// Receives playback events from an ``AudioClipPlayer``.
@MainActor public protocol AudioClipPlayerDelegate: AnyObject {
    /// Returns a `Resource` providing access to the audio data for `link`.
    ///
    /// The player calls this to open a publication resource by link.
    func audioClipPlayer(_ player: any AudioClipPlayer, resourceFor link: Link) throws -> Resource

    /// Called when the player finishes playing a clip, either because it
    /// reached `clip.end` or because `seek(to:)` was called past that point.
    func audioClipPlayer(_ player: any AudioClipPlayer, didFinishPlaying clip: AudioClip)

    /// Called when playback reaches a marker position within the current clip.
    func audioClipPlayer(_ player: any AudioClipPlayer, didReachMarker marker: AudioClip.Marker)

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
