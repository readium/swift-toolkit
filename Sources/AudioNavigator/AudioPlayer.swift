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
public protocol AudioPlayer: AnyObject, Sendable {
    /// Delegate that receives playback events and requests from the player.
    var delegate: (any AudioPlayerDelegate)? { get set }

    /// Current playback status.
    var status: AudioPlayerStatus { get }

    /// Current playback position within the current clip, in seconds.
    var time: TimeInterval { get }

    /// Duration of the current clip in seconds, if known.
    var duration: TimeInterval? { get }

    /// Best-effort hint to start buffering a clip before it is needed.
    ///
    /// Called while the current clip is playing so the next clip's asset is
    /// ready when `play()` is called. Implementations that cannot benefit (e.g.
    /// local files that load instantly) may ignore this.
    ///
    /// It is always possible to call `play()` on an unprepared clip.
    func prepare(_ clip: AudioClip)

    /// Plays the given clip immediately, replacing any current playback.
    ///
    /// The player plays from `clip.start` to `clip.end` (or the end of the
    /// file when `end` is `nil`), firing
    /// ``AudioPlayerDelegate/audioPlayer(_:didReachMarker:)`` as each marker
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
    /// ``AudioPlayerDelegate/audioPlayer(_:didFinishPlaying:)``.
    ///
    /// This may be called from within a
    /// ``AudioPlayerDelegate/audioPlayer(_:didReachMarker:)`` callback, for
    /// example to skip a gap to the start of the next playback item.
    func seek(to time: TimeInterval)
}

/// Receives playback events from an ``AudioPlayer``.
@MainActor public protocol AudioPlayerDelegate: AnyObject {
    /// Returns a `Resource` providing access to the audio data for `link`.
    ///
    /// The player calls this to open a publication resource by link.
    func audioPlayer(_ player: any AudioPlayer, resourceFor link: Link) throws -> Resource

    /// Called when the player finishes playing a clip, either because it
    /// reached `clip.end` or because `seek(to:)` was called past that point.
    func audioPlayer(_ player: any AudioPlayer, didFinishPlaying clip: AudioClip)

    /// Called when playback reaches a marker position within the current clip.
    func audioPlayer(_ player: any AudioPlayer, didReachMarker marker: AudioMarker)

    /// Called periodically with the current playback position within the
    /// current clip, in seconds.
    func audioPlayer(_ player: any AudioPlayer, didUpdateTime time: TimeInterval)

    /// Called when the player's playback status changes.
    func audioPlayer(_ player: any AudioPlayer, didChangeStatus status: AudioPlayerStatus)

    /// Called when an unrecoverable error occurs while playing `clip`.
    /// The player transitions to `idle` status (as if `stop()` was called).
    func audioPlayer(_ player: any AudioPlayer, didFailPlaying clip: AudioClip, withError error: Error)
}

/// A bounded region of an audio file to play, with optional markers.
///
/// The player plays from `start` to `end`, firing a delegate callback each
/// time a marker position is reached.
public struct AudioClip: Hashable, Sendable {
    /// Publication link for the audio resource, carrying the URL and media type.
    public var link: Link

    /// Start of the clip, in seconds from the beginning of the resource.
    public var start: TimeInterval

    /// End of the clip, in seconds from the beginning of the resource.
    ///
    /// When `nil`, the clip plays to the end of the audio resource.
    public var end: TimeInterval?

    /// Markers at which the player notifies the delegate.
    ///
    /// Positions are expressed in seconds from the beginning of the resource,
    /// within the start-end range.
    public var markers: [AudioMarker]

    public init(
        link: Link,
        start: TimeInterval,
        end: TimeInterval? = nil,
        markers: [AudioMarker] = []
    ) {
        self.link = link
        self.start = start
        self.end = end
        self.markers = markers
    }
}

/// A labelled position within an ``AudioClip`` at which the player notifies
/// its delegate.
public struct AudioMarker: Hashable, Sendable {
    /// Unique identifier for this marker.
    public var id: UUID

    /// Position of the marker in seconds from the beginning of the audio
    /// resource, within the enclosing clip's start-end range.
    public var time: TimeInterval

    public init(
        id: UUID = UUID(),
        time: TimeInterval
    ) {
        self.id = id
        self.time = time
    }
}

/// The playback status of an ``AudioPlayer``.
///
/// Transitions typically follow: ``idle`` → ``loading`` → ``playing``.
/// Rebuffering mid-playback moves from ``playing`` back to ``loading``.
/// An explicit ``AudioPlayer/pause()`` call moves to ``paused`` from any
/// non-idle state.
public enum AudioPlayerStatus: Hashable, Sendable {
    /// No clip is loaded. The player is waiting for a ``AudioPlayer/play(_:)``
    /// call.
    case idle

    /// The player intends to play, but the clip is loading or waiting for
    /// enough data to start or resume.
    case loading

    /// The player is actively playing audio.
    case playing

    /// Playback is paused. The player will resume from the current position
    /// when ``AudioPlayer/resume()`` is called.
    case paused
}
