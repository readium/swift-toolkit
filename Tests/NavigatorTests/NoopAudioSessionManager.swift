//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared

/// An `AudioSessionManaging` no-op, to drive a player under test without
/// activating the process-wide audio session.
final class NoopAudioSessionManager: AudioSessionManaging {
    func start(with user: any AudioSessionUser, isPlaying: Bool) async {}

    func end(with user: any AudioSessionUser) {}

    func user(_ user: any AudioSessionUser, didChangePlaying isPlaying: Bool) {}
}
