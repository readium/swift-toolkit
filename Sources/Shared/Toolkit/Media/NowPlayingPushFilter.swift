//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Decides which playback updates must be pushed to the system Now Playing
/// info.
///
/// The system computes the elapsed time from the last pushed one and the
/// playback rate, so Apple recommends pushing only when the position,
/// duration or rate changes, instead of periodically. Callers may report their
/// playback continuously though, without telling when it jumps (e.g. a seek).
/// Comparing with the extrapolated elapsed time is how we tell such a jump,
/// which must be pushed immediately, from a regular progress, which must not.
struct NowPlayingPushFilter {
    /// Maximum gap between the elapsed time and the one extrapolated by the
    /// system, beyond which the playback is considered to have jumped.
    let tolerance: TimeInterval

    /// Returns the current time, in seconds, from a monotonic clock.
    private let now: () -> TimeInterval

    /// Playback pushed last to the system, and when it was pushed.
    private var lastPush: (playback: NowPlayingInfo.Playback, pushedAt: TimeInterval)?

    init(
        tolerance: TimeInterval = 0.5,
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.tolerance = tolerance
        self.now = now
    }

    /// Returns whether `playback` must be pushed, because it differs from the
    /// last push by more than an elapsed time extrapolated by the system.
    func shouldPush(_ playback: NowPlayingInfo.Playback) -> Bool {
        guard
            let lastPush,
            let elapsedTime = playback.elapsedTime,
            let pushedElapsedTime = lastPush.playback.elapsedTime
        else {
            return true
        }
        var pushedPlayback = lastPush.playback
        pushedPlayback.elapsedTime = elapsedTime
        guard pushedPlayback == playback else {
            return true
        }

        let extrapolatedElapsedTime = pushedElapsedTime + (lastPush.playback.rate ?? 0) * (now() - lastPush.pushedAt)
        return abs(elapsedTime - extrapolatedElapsedTime) > tolerance
    }

    /// Records that `playback` was pushed to the system.
    mutating func didPush(_ playback: NowPlayingInfo.Playback) {
        lastPush = (playback, now())
    }

    /// Forgets the last push, after the Now Playing info was cleared.
    mutating func reset() {
        lastPush = nil
    }
}
