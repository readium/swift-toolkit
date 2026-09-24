//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

enum NowPlayingPushFilterTests {
    struct FirstPush {
        @Test func pushesWithoutPreviousPush() {
            let filter = NowPlayingPushFilter()
            #expect(filter.shouldPush(playback(elapsedTime: 10, rate: 1)))
        }

        @Test func pushesAfterReset() {
            let clock = FakeClock()
            var filter = NowPlayingPushFilter(now: clock.now)
            filter.didPush(playback(elapsedTime: 10, rate: 1))

            filter.reset()

            #expect(filter.shouldPush(playback(elapsedTime: 10, rate: 1)))
        }
    }

    struct Progress {
        /// The system extrapolates the elapsed time from the rate, so a
        /// matching progress is not pushed.
        @Test("Skips the progress extrapolated by the system", arguments: [
            (rate: 1.0, elapsedTime: 12.0),
            (rate: 2.0, elapsedTime: 14.0),
            (rate: 0.5, elapsedTime: 11.0),
            (rate: 0.0, elapsedTime: 10.0),
        ])
        func skipsExtrapolatedProgress(rate: Double, elapsedTime: Double) {
            let clock = FakeClock()
            var filter = NowPlayingPushFilter(now: clock.now)
            filter.didPush(playback(elapsedTime: 10, rate: rate))

            clock.advance(by: 2)

            #expect(!filter.shouldPush(playback(elapsedTime: elapsedTime, rate: rate)))
        }

        /// A missing rate doesn't advance the extrapolated elapsed time.
        @Test func missingRateIsExtrapolatedAsPaused() {
            let clock = FakeClock()
            var filter = NowPlayingPushFilter(now: clock.now)
            filter.didPush(playback(elapsedTime: 10, rate: nil))

            clock.advance(by: 2)

            #expect(!filter.shouldPush(playback(elapsedTime: 10, rate: nil)))
            #expect(filter.shouldPush(playback(elapsedTime: 12, rate: nil)))
        }

        /// The extrapolation starts from the last push, not from the first
        /// one.
        @Test func extrapolatesFromTheLastPush() {
            let clock = FakeClock()
            var filter = NowPlayingPushFilter(now: clock.now)
            filter.didPush(playback(elapsedTime: 10, rate: 1))
            clock.advance(by: 5)
            filter.didPush(playback(elapsedTime: 50, rate: 1))

            clock.advance(by: 2)

            #expect(!filter.shouldPush(playback(elapsedTime: 52, rate: 1)))
        }
    }

    struct Jumps {
        @Test("Pushes an elapsed time beyond the tolerance", arguments: [
            // Seeks.
            (elapsedTime: 40.0, isPushed: true),
            (elapsedTime: 2.0, isPushed: true),
            // Drift, e.g. a stall.
            (elapsedTime: 11.4, isPushed: true),
            (elapsedTime: 12.6, isPushed: true),
            // Within the tolerance.
            (elapsedTime: 11.6, isPushed: false),
            (elapsedTime: 12.4, isPushed: false),
        ])
        func pushesBeyondTolerance(elapsedTime: Double, isPushed: Bool) {
            let clock = FakeClock()
            var filter = NowPlayingPushFilter(tolerance: 0.5, now: clock.now)
            filter.didPush(playback(elapsedTime: 10, rate: 1))

            clock.advance(by: 2)

            #expect(filter.shouldPush(playback(elapsedTime: elapsedTime, rate: 1)) == isPushed)
        }

        /// While paused, any change of the elapsed time is a seek.
        @Test func pushesASeekWhilePaused() {
            let clock = FakeClock()
            var filter = NowPlayingPushFilter(now: clock.now)
            filter.didPush(playback(elapsedTime: 10, rate: 0))

            clock.advance(by: 30)

            #expect(filter.shouldPush(playback(elapsedTime: 20, rate: 0)))
        }
    }

    struct OtherChanges {
        @Test("Pushes any change other than the elapsed time", arguments: [
            NowPlayingInfo.Playback(chapterNumber: 1, duration: 100, elapsedTime: 12, rate: 0),
            NowPlayingInfo.Playback(chapterNumber: 1, duration: 100, elapsedTime: 12, rate: 2),
            NowPlayingInfo.Playback(chapterNumber: 1, duration: 200, elapsedTime: 12, rate: 1),
            NowPlayingInfo.Playback(chapterNumber: 2, duration: 100, elapsedTime: 12, rate: 1),
        ])
        func pushesOtherChanges(playback: NowPlayingInfo.Playback) {
            let clock = FakeClock()
            var filter = NowPlayingPushFilter(now: clock.now)
            filter.didPush(NowPlayingInfo.Playback(chapterNumber: 1, duration: 100, elapsedTime: 10, rate: 1))

            clock.advance(by: 2)

            #expect(filter.shouldPush(playback))
        }

        /// Without an elapsed time, there is nothing to extrapolate.
        @Test func pushesAMissingElapsedTime() {
            let clock = FakeClock()
            var filter = NowPlayingPushFilter(now: clock.now)
            filter.didPush(playback(elapsedTime: 10, rate: 1))
            #expect(filter.shouldPush(playback(elapsedTime: nil, rate: 1)))

            filter.didPush(playback(elapsedTime: nil, rate: 1))
            #expect(filter.shouldPush(playback(elapsedTime: 10, rate: 1)))
        }
    }
}

// MARK: - Helpers

private func playback(elapsedTime: Double?, rate: Double?) -> NowPlayingInfo.Playback {
    NowPlayingInfo.Playback(chapterNumber: 1, duration: 100, elapsedTime: elapsedTime, rate: rate)
}

/// Monotonic clock advanced manually.
private final class FakeClock {
    private var time: TimeInterval = 1000

    func now() -> TimeInterval {
        time
    }

    func advance(by interval: TimeInterval) {
        time += interval
    }
}
