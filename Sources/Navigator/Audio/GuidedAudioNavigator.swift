//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Receives high-level playback events from an ``GuidedAudioNavigator``.
@MainActor public protocol GuidedAudioNavigatorDelegate: AnyObject {
    /// Called when the navigator's playback status changes.
    func navigator(_ navigator: GuidedAudioNavigator, didChangeStatus status: PlaybackStatus)

    /// Called when the actively narrated location changes.
    // FIXME: Periodic time observer?
    func navigator(_ navigator: GuidedAudioNavigator, didChangeLocation location: any Location)

    /// Called when an unrecoverable error occurs.
    ///
    /// The navigator transitions to ``PlaybackStatus/paused`` status. The
    /// delegate should surface the error to the user and may attempt to resume.
    func navigator(_ navigator: GuidedAudioNavigator, didFailWithError error: Error)
}

/// The reference frame for a time or duration query.
public enum TimeScope {
    /// Relative to the whole publication.
    case publication

    /// Relative to the currently playing audio resource.
    case resource
}

/// The playback state of an ``GuidedAudioNavigator``.
public enum PlaybackStatus: Hashable {
    /// Playback is paused or has not yet started.
    case paused

    /// The navigator intends to play but is waiting for audio data to load or
    /// buffer.
    case loading

    /// The navigator is actively playing audio.
    case playing
}

/// Plays audio nodes from a ``GuidedNavigationCursor`` with an
/// ``AudioClipPlayer``.
@MainActor public final class GuidedAudioNavigator: Sendable {
    /// Registers a block to be called at regular intervals while playing.
    ///
    /// - Parameters:
    ///   - interval: How often to fire the block, in seconds. Defaults to 0.5.
    ///   - block: Receives the navigator so callers can read `time(in:)` and
    ///     `duration(of:)`. Only fires when the narrator that ticked is the
    ///     active narrator.
    /// - Returns: An opaque token that must be retained for as long as the
    ///   observation should remain active. Releasing the token cancels the
    ///   observer.
    public func addPeriodicTimeObserver(
        forInterval interval: TimeInterval = 0.5,
        using block: @escaping (GuidedAudioNavigator) -> Void
    ) -> Any {
        fatalError("TODO")
    }

    /// Event callbacks for the navigator.
    public weak var delegate: (any GuidedAudioNavigatorDelegate)?

    /// The last activated `GuidedNavigationNode`.
    public private(set) var currentItem: GuidedNavigationNode?

    private let publication: Publication
    private let cursor: GuidedNavigationCursor
    private let player: AudioClipPlayer

    public init?(
        publication: Publication,
        readingOrder: [AnyURL]? = nil,
        player: AudioClipPlayer? = nil
    ) {
        guard let cursor = GuidedNavigationCursor(publication: publication, readingOrder: readingOrder) else {
            return nil
        }

        self.publication = publication
        self.cursor = cursor
        self.player = player ?? DefaultAudioClipPlayer()
    }

    /// Current playback status.
    public var status: PlaybackStatus {
        return switch player.status {
        case .idle: .paused
        case .loading: .loading
        case .playing: .playing
        case .paused: .paused
        }
    }

    /// Returns the current playback position within `scope`, in seconds, or
    /// `nil` if no item is currently active or the time for the requested scope
    /// cannot be determined.
    public func time(in scope: TimeScope) -> TimeInterval? {
        nil
    }

    /// Returns the total duration of `scope` in seconds, or `nil` if it is not
    /// yet known, or the duration for the requested scope cannot be determined.
    public func duration(of scope: TimeScope) -> TimeInterval? {
        nil
    }

    // MARK: - Playback control

    /// Begins playback from the current cursor position.
    public func play() {}

    /// Pauses the playback. Has no effect when already paused or idle.
    public func pause() {}

    /// Resumes the playback from the current position. Has no effect when not
    /// paused.
    public func resume() {}

    /// Skips to the next playback item.
    public func skipForward() {}

    /// Skips to the previous playback item.
    public func skipBackward() {}

    /// Skips to the next reading order resource.
    public func skipToNextResource() async {}

    /// Skips to the previous reading order resource.
    public func skipToPreviousResource() async {}
}
