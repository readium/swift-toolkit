//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Protocol for a navigator rendering an audio or video based publication.
///
/// **WARNING:** This API is experimental and may change or be removed in a
/// future release without notice. Use with caution.
public protocol _MediaNavigator: Navigator {
    /// Total duration in the publication, if known.
    var totalDuration: Double? { get }

    /// Volume of playback, from 0.0 to 1.0.
    var volume: Double { get set }

    /// Speed of playback.
    /// Default is 1.0
    var rate: Double { get set }

    /// Returns whether the resource is currently playing or not.
    var state: MediaPlaybackState { get }

    /// Resumes or start the playback.
    func play()

    /// Pauses the playback.
    func pause()

    /// Seeks to the given time in the current resource.
    func seek(to time: Double)

    /// Seeks relatively from the current time in the current resource.
    func seek(by delta: Double)
}

public extension _MediaNavigator {
    /// Toggles the playback.
    func playPause() {
        switch state {
        case .loading, .playing:
            pause()
        case .paused:
            play()
        }
    }
}

/// Status of a played media resource.
public enum MediaPlaybackState {
    case paused
    case loading
    case playing
}

/// Holds metadata about a played media resource.
public struct MediaPlaybackInfo {
    /// Index of the current resource in the `readingOrder`.
    public let resourceIndex: Int

    /// Indicates whether the resource is currently playing or not.
    public let state: MediaPlaybackState

    /// Current playback position in the resource, in seconds.
    public let time: Double

    /// Duration in seconds of the resource, if known.
    public let duration: Double?

    /// Progress in the resource, from 0 to 1.
    public var progress: Double {
        guard let duration = duration else {
            return 0
        }
        return time / duration
    }

    public init(
        resourceIndex: Int = 0,
        state: MediaPlaybackState = .loading,
        time: Double = 0,
        duration: Double? = nil
    ) {
        self.resourceIndex = resourceIndex
        self.state = state
        self.time = time
        self.duration = duration
    }
}

public protocol _MediaNavigatorDelegate: NavigatorDelegate {
    /// Called when the playback updates.
    func navigator(_ navigator: _MediaNavigator, playbackDidChange info: MediaPlaybackInfo)

    /// Called when the navigator finished playing the current resource.
    /// Returns whether the next resource should be played. Default is true.
    func navigator(_ navigator: _MediaNavigator, shouldPlayNextResource info: MediaPlaybackInfo) -> Bool

    /// Called when the ranges of buffered media data change.
    /// Warning: They may be discontinuous.
    func navigator(_ navigator: _MediaNavigator, loadedTimeRangesDidChange ranges: [Range<Double>])
}

public extension _MediaNavigatorDelegate {
    func navigator(_ navigator: _MediaNavigator, playbackDidChange info: MediaPlaybackInfo) {}

    func navigator(_ navigator: _MediaNavigator, shouldPlayNextResource info: MediaPlaybackInfo) -> Bool { true }

    func navigator(_ navigator: _MediaNavigator, loadedTimeRangesDidChange ranges: [Range<Double>]) {}
}
