//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared

/// An `AudioSessionManaging` recording whether its user reported playing, to
/// check when the audio session would be released.
final class RecordingAudioSessionManager: AudioSessionManaging {
    /// Values reported with `user(_:didChangePlaying:)`, in order.
    ///
    /// A value repeating the previous one is ignored, as `AudioSession` does.
    private(set) var reportedPlaying: [Bool] = []

    func start(with user: any AudioSessionUser, isPlaying: Bool) async {}

    func end(with user: any AudioSessionUser) {}

    func user(_ user: any AudioSessionUser, didChangePlaying isPlaying: Bool) {
        guard reportedPlaying.last != isPlaying else {
            return
        }
        reportedPlaying.append(isPlaying)
    }
}
