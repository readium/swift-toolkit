//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared

/// An `AudioSessionManaging` whose audio session is not ready until `resume()`
/// is called, to test a player waiting for it.
final class SuspendingAudioSessionManager: AudioSessionManaging {
    private var isReady = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    /// Makes the audio session ready, returning from the pending and future
    /// `start(with:isPlaying:)` calls.
    func resume() {
        isReady = true
        for continuation in continuations {
            continuation.resume()
        }
        continuations = []
    }

    func start(with user: any AudioSessionUser, isPlaying: Bool) async {
        guard !isReady else {
            return
        }
        await withCheckedContinuation { continuations.append($0) }
    }

    func end(with user: any AudioSessionUser) {}

    func user(_ user: any AudioSessionUser, didChangePlaying isPlaying: Bool) {}
}
