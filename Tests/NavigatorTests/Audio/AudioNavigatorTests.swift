//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumNavigator
import ReadiumShared
import Testing

enum AudioNavigatorTests {
    @Suite("Reaching the end of the publication") @MainActor struct EndOfPublication {
        private let audiobook = Audiobook()

        @Test("seeking up to the end of the last resource ends the playback")
        func seekToEndOfLastResource() async {
            // Given the last resource.
            await audiobook.goToResource(at: lastTrackIndex)

            // When seeking up to its end.
            await audiobook.navigator.seek(to: trackDuration)

            // Then the playback is ended, at the end of the last resource.
            #expect(audiobook.navigator.state == .ended)
            #expect(audiobook.states.last == .ended)
            #expect(audiobook.navigator.playbackInfo.resourceIndex == lastTrackIndex)
            #expect(abs(audiobook.navigator.playbackInfo.time - trackDuration) < 0.1)
        }

        @Test("skipping past the end of the publication ends the playback")
        func skipPastEndOfPublication() async {
            // Given the first resource.
            await audiobook.goToResource(at: 0)

            // When skipping by more than the duration of the publication.
            await audiobook.navigator.seek(by: publicationDuration + 1)

            // Then the playback is ended in the last resource.
            #expect(audiobook.navigator.state == .ended)
            #expect(audiobook.states.last == .ended)
            #expect(audiobook.navigator.playbackInfo.resourceIndex == lastTrackIndex)
        }

        @Test("playing up to the end of the last resource ends the playback", .timeLimit(.minutes(1)))
        func playToEndOfLastResource() async {
            // Given a position shortly before the end of the last resource.
            await audiobook.goShortlyBeforeEnd()

            // When playing.
            audiobook.navigator.play()

            // Then the playback is ended after playing the remaining audio.
            await audiobook.waitForPlayback { $0.state == .ended }
            #expect(audiobook.states.contains(.playing))
            #expect(audiobook.navigator.state == .ended)
            #expect(audiobook.navigator.playbackInfo.resourceIndex == lastTrackIndex)
        }
    }

    @Suite("Reaching the end of another resource") @MainActor struct EndOfOtherResource {
        private let audiobook = Audiobook()

        @Test("seeking up to the end of the resource moves on to the next one")
        func seekToEndOfResource() async {
            // Given the first resource.
            await audiobook.goToResource(at: 0)

            // When seeking up to its end.
            await audiobook.navigator.seek(to: trackDuration)

            // Then the navigator moved on to the second resource, without
            // ending the playback.
            #expect(audiobook.navigator.playbackInfo.resourceIndex == 1)
            #expect(audiobook.navigator.state == .paused)
            #expect(!audiobook.states.contains(.ended))
        }

        @Test("a playback held by the delegate at the end of the resource is paused")
        func heldAtEndOfResource() async {
            // Given the first resource, and a delegate refusing to play the
            // next one.
            audiobook.playsNextResource = false
            await audiobook.goToResource(at: 0)

            // When seeking up to its end.
            await audiobook.navigator.seek(to: trackDuration)

            // Then the playback is paused in the first resource, not ended.
            #expect(audiobook.navigator.playbackInfo.resourceIndex == 0)
            #expect(audiobook.navigator.state == .paused)
            #expect(!audiobook.states.contains(.ended))
        }
    }

    @Suite("Once the playback is ended") @MainActor struct Ended {
        private let audiobook = Audiobook()

        /// Given a playback ended by seeking up to the end of the publication.
        init() async {
            await audiobook.goToResource(at: lastTrackIndex)
            await audiobook.navigator.seek(to: trackDuration)
            #expect(audiobook.navigator.state == .ended)
        }

        @Test("pausing and stopping keep it ended")
        func pauseAndStop() {
            // When pausing, then the playback is still ended.
            audiobook.navigator.pause()
            #expect(audiobook.navigator.state == .ended)

            // When stopping, then the playback is still ended.
            audiobook.navigator.stop()
            #expect(audiobook.navigator.state == .ended)
        }

        @Test("seeking back pauses it")
        func seekBack() async {
            // When skipping backward.
            await audiobook.navigator.seek(by: -1)

            // Then the playback is paused in the last resource.
            #expect(audiobook.navigator.state == .paused)
            #expect(audiobook.states.last == .paused)
            #expect(audiobook.navigator.playbackInfo.resourceIndex == lastTrackIndex)
        }

        @Test("jumping to a resource pauses it")
        func jump() async {
            // When jumping to another resource.
            await audiobook.goToResource(at: 1)

            // Then the playback is paused.
            #expect(audiobook.navigator.state == .paused)
            #expect(audiobook.states.last == .paused)
        }

        @Test("playing restarts from the beginning of the publication", .timeLimit(.minutes(1)))
        func play() async throws {
            // When playing.
            audiobook.navigator.play()

            // Then the first resource is playing from its start.
            let playback = try #require(
                await audiobook.waitForPlayback { $0.state == .playing && $0.resourceIndex == 0 }
            )
            #expect(playback.time < trackDuration / 2)
            audiobook.navigator.pause()
        }
    }

    @Suite("shouldPlayNextResource") @MainActor struct ShouldPlayNextResource {
        private let audiobook = Audiobook()

        @Test("is called at the end of each resource but the last one")
        func calledUnlessLastResource() async {
            // Given the first resource.
            await audiobook.goToResource(at: 0)

            // When skipping past the end of the publication.
            await audiobook.navigator.seek(by: publicationDuration + 1)

            // Then the delegate was asked for the first two resources only.
            #expect(audiobook.shouldPlayNextResourceCalls == [0, 1])
        }

        @Test("is not called after playing the last resource", .timeLimit(.minutes(1)))
        func notCalledAfterPlayingLastResource() async {
            // Given a position shortly before the end of the last resource.
            await audiobook.goShortlyBeforeEnd()

            // When playing up to the end of the publication.
            audiobook.navigator.play()
            await audiobook.waitForPlayback { $0.state == .ended }

            // Then the delegate was never asked.
            #expect(audiobook.shouldPlayNextResourceCalls.isEmpty)
        }
    }
}

private let trackCount = 3
private let trackDuration: Double = 2
private let lastTrackIndex = trackCount - 1
private let publicationDuration = Double(trackCount) * trackDuration

/// An audiobook of `trackCount` silent tracks played by a real
/// `AudioNavigator`, recording the events sent to its delegate.
@MainActor private final class Audiobook: AudioNavigatorDelegate {
    let navigator: AudioNavigator

    /// Answer to the navigator asking whether to play the next resource.
    var playsNextResource = true

    /// Playback states reported by the navigator.
    private(set) var states: [MediaPlaybackState] = []

    /// Playbacks reported by the navigator, buffered until they are waited
    /// for.
    private let playbacks: AsyncStream<MediaPlaybackInfo>
    private let playbacksContinuation: AsyncStream<MediaPlaybackInfo>.Continuation

    /// Indices of the resources for which the navigator asked whether to play
    /// the next one.
    private(set) var shouldPlayNextResourceCalls: [Int] = []

    init() {
        (playbacks, playbacksContinuation) = AsyncStream.makeStream()

        let hrefs = (1 ... trackCount).map { "track\($0).wav" }
        let track = WAV.silence(duration: trackDuration)

        navigator = AudioNavigator(
            publication: Publication(
                manifest: Manifest(
                    metadata: Metadata(conformsTo: [.audiobook], title: "Audiobook"),
                    readingOrder: hrefs.map {
                        Link(href: $0, mediaType: .wav, duration: trackDuration)
                    }
                ),
                container: DataContainer(
                    entries: Dictionary(uniqueKeysWithValues: hrefs.map { (AnyURL(string: $0)!, track) })
                )
            ),
            audioSession: NoopAudioSessionManager()
        )
        navigator.delegate = self
    }

    /// Jumps to the start of the resource at `index` in the reading order.
    func goToResource(at index: Int) async {
        #expect(await navigator.go(to: navigator.readingOrder[index]))
    }

    /// Jumps shortly before the end of the last resource, so that playing
    /// reaches the end of the publication quickly.
    func goShortlyBeforeEnd() async {
        await goToResource(at: lastTrackIndex)
        await navigator.seek(to: trackDuration - 0.3)
    }

    /// Waits for the navigator to report a playback matching `condition`.
    ///
    /// The playbacks reported before waiting are checked too.
    @discardableResult
    func waitForPlayback(where condition: (MediaPlaybackInfo) -> Bool) async -> MediaPlaybackInfo? {
        for await playback in playbacks where condition(playback) {
            return playback
        }
        return nil
    }

    func navigator(_ navigator: AudioNavigator, playbackDidChange info: MediaPlaybackInfo) {
        states.append(info.state)
        playbacksContinuation.yield(info)
    }

    func navigator(_ navigator: AudioNavigator, shouldPlayNextResource info: MediaPlaybackInfo) -> Bool {
        shouldPlayNextResourceCalls.append(info.resourceIndex)
        return playsNextResource
    }

    func navigator(_ navigator: Navigator, presentError error: NavigatorError) {}
}
