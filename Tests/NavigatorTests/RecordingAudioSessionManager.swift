//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import Testing
import TestSupport

/// An `AudioSessionManaging` recording whether its user reported playing, to
/// check when the audio session would be released.
final class RecordingAudioSessionManager: AudioSessionManaging {
    /// Values reported with `user(_:didChangePlaying:)`, in order.
    ///
    /// A value repeating the previous one is ignored, as `AudioSession` does.
    private(set) var reportedPlaying: [Bool] = []

    /// Reported values, buffered until they are waited for.
    private let reports: AsyncStream<Bool>
    private let reportsContinuation: AsyncStream<Bool>.Continuation

    init() {
        (reports, reportsContinuation) = AsyncStream.makeStream()
    }

    /// Waits for the next report of `isPlaying`, or fails the test after
    /// `timeout` seconds.
    ///
    /// The values reported before waiting are checked too, in order.
    func waitForReport(
        _ isPlaying: Bool,
        timeout: TimeInterval = .testTimeout,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        guard await reports.first(within: timeout, where: { $0 == isPlaying }) != nil else {
            Issue.record("Timed out waiting for a report of \(isPlaying)", sourceLocation: sourceLocation)
            return
        }
    }

    func start(with user: any AudioSessionUser, isPlaying: Bool) async {}

    func end(with user: any AudioSessionUser) {}

    func user(_ user: any AudioSessionUser, didChangePlaying isPlaying: Bool) {
        guard reportedPlaying.last != isPlaying else {
            return
        }
        reportedPlaying.append(isPlaying)
        reportsContinuation.yield(isPlaying)
    }
}
