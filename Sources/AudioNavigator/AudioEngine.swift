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
public protocol AudioEngine: AnyObject, Sendable {
    /// Delegate that receives playback events and requests from the engine.
    var delegate: (any AudioEngineDelegate)? { get set }

    /// Current playback status.
    var status: AudioEngineStatus { get }

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
    /// The engine plays from `clip.start` to `clip.end` (or the end of the
    /// file when `end` is `nil`), firing
    /// ``AudioEngineDelegate/audioEngine(_:didReachMarker:)`` as each marker
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
    /// firing. If `time` is past the clip's `end`, the engine behaves as if
    /// the clip finished naturally and fires
    /// ``AudioEngineDelegate/audioEngine(_:didFinishPlaying:)``.
    ///
    /// This may be called from within a
    /// ``AudioEngineDelegate/audioEngine(_:didReachMarker:)`` callback, for
    /// example to skip a gap to the start of the next playback item.
    func seek(to time: TimeInterval)
}

/// Receives playback events from an ``AudioEngine``.
@MainActor public protocol AudioEngineDelegate: AnyObject {
    /// Returns a `Resource` providing access to the audio data at `href`.
    ///
    /// The engine calls this to open a publication resource by URL. Throwing
    /// an error might transitions the engine to ``AudioEngineStatus/failed(_:)``.
    func audioEngine(_ engine: any AudioEngine, resourceAt href: AnyURL) throws -> Resource

    /// Called when the engine finishes playing a clip, either because it
    /// reached `clip.end` or because `seek(to:)` was called past that point.
    func audioEngine(_ engine: any AudioEngine, didFinishPlaying clip: AudioClip)

    /// Called when playback reaches a marker position within the current clip.
    func audioEngine(_ engine: any AudioEngine, didReachMarker marker: AudioMarker)

    /// Called periodically with the current playback position within the
    /// current clip, in seconds.
    func audioEngine(_ engine: any AudioEngine, didUpdateTime time: TimeInterval)

    /// Called when the engine's playback status changes.
    func audioEngine(_ engine: any AudioEngine, didChangeStatus status: AudioEngineStatus)
}

/// A bounded region of an audio file to play, with optional markers.
///
/// The engine plays from `start` to `end`, firing a delegate callback each
/// time a marker position is reached.
public struct AudioClip: Hashable, Sendable {
    /// URL of the audio resource within the publication.
    public var href: AnyURL

    /// Start of the clip, in seconds from the beginning of the resource.
    public var start: TimeInterval

    /// End of the clip, in seconds from the beginning of the resource.
    ///
    /// When `nil`, the clip plays to the end of the audio resource.
    public var end: TimeInterval?

    /// Markers at which the engine notifies the delegate.
    ///
    /// Positions are expressed in seconds from the beginning of the resource,
    /// within the start-end range.
    public var markers: [AudioMarker]

    public init(
        href: AnyURL,
        start: TimeInterval,
        end: TimeInterval? = nil,
        markers: [AudioMarker] = []
    ) {
        self.href = href
        self.start = start
        self.end = end
        self.markers = markers
    }
}

/// A labelled position within an ``AudioClip`` at which the engine notifies
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

/// The playback status of an ``AudioEngine``.
///
/// Transitions typically follow: ``idle`` → ``buffering`` → ``playing``.
/// Rebuffering mid-playback moves from ``playing`` back to ``buffering``.
/// An explicit ``AudioEngine/pause()`` call moves to ``paused`` from any
/// non-idle state.
public enum AudioEngineStatus {
    /// No clip is loaded. The engine is waiting for a ``AudioEngine/play(_:)``
    /// call.
    case idle

    /// A clip is loaded and the engine intends to play, but is waiting for
    /// enough data to start or resume.
    case buffering

    /// The engine is actively playing audio.
    case playing

    /// Playback is paused. The engine will resume from the current position
    /// when ``AudioEngine/resume()`` is called.
    case paused

    /// The engine encountered an unrecoverable error and cannot continue.
    case failed(Error)
}
