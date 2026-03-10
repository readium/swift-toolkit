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

/// Plays audio clips from a Publication's Guided Navigation.
@MainActor public final class GuidedAudioNavigator: Sendable, Loggable {
    /// Event callbacks for the navigator.
    public weak var delegate: (any GuidedAudioNavigatorDelegate)?

    private let publication: Publication

    /// Sequences the stream of ``GuidedNavigationNode`` into coalesced
    /// ``GuidedAudioClip`` ready for the `player`.
    private let sequencer: GuidedAudioSequencer

    /// Renders the ``GuidedAudioClip``.
    private let player: any AudioClipPlayer

    /// The clip currently loaded in the player.
    private var currentClip: GuidedAudioClip?

    /// Index of the current node/segment within the `currentClip`.
    private var currentNodeIndex: Int?

    /// Precomputed prefix sums of segment durations for `currentClip`.
    /// `cumulativeElapsed[i]` is the total playback time before segment `i`.
    /// Recomputed each time a new clip is loaded.
    private var cumulativeElapsed: [TimeInterval] = []

    public init?(
        publication: Publication,
        readingOrder: [AnyURL]? = nil
    ) {
        guard let cursor = GuidedNavigationCursor(publication: publication, readingOrder: readingOrder) else {
            return nil
        }

        self.publication = publication
        sequencer = GuidedAudioSequencer(publication: publication, cursor: cursor)
        player = DefaultAudioClipPlayer()
        player.delegate = self
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

    // MARK: - Time

    /// The reference frame for a time or duration query.
    public enum TimeScope {
        /// Relative to the whole publication.
        case publication

        /// Relative to the currently playing audio resource.
        case resource
    }

    /// Returns the current playback position within `scope`, in seconds, or
    /// `nil` if no item is currently active or the time for the requested scope
    /// cannot be determined.
    public func time(in scope: TimeScope) -> TimeInterval? {
        guard
            let clip = currentClip,
            let nodeIndex = currentNodeIndex,
            nodeIndex < cumulativeElapsed.count
        else { return nil }
        switch scope {
        case .resource:
            return cumulativeElapsed[nodeIndex]
                + max(0, player.time - clip.clip.segments[nodeIndex].start)
        case .publication:
            return nil
        }
    }

    /// Returns the total duration of `scope` in seconds, or `nil` if it is not
    /// yet known, or the duration for the requested scope cannot be determined.
    public func duration(of scope: TimeScope) -> TimeInterval? {
        guard let clip = currentClip else { return nil }
        switch scope {
        case .resource:
            return clip.clip.duration(fileDuration: player.duration)
        case .publication:
            return publication.metadata.duration
        }
    }

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
        player.addPeriodicTimeObserver(forInterval: interval) { [weak self] in
            guard let self else { return }
            block(self)
        }
    }

    // MARK: - Playback control

    /// Begins playback from the start of the publication.
    public func play() {
        log(.debug, "play()")
        Task {
            guard let clip = await sequencer.next() else {
                log(.warning, "play(): no clips available in the publication")
                return
            }
            load(clip, startAt: 0)
        }
    }

    /// Begins playback from the given location in the publication's reading
    /// order.
    public func play(from location: any ReferenceLocation) {
        log(.debug, "play(from:) location=\(location)")
        guard let ref = extractReference(from: location) else {
            log(.warning, "play(from:): location has no reference, ignoring")
            return
        }
        Task {
            guard let (clip, startIndex) = await sequencer.seek(to: ref) else {
                log(.warning, "play(from:): could not seek to reference \(ref)")
                return
            }
            load(clip, startAt: startIndex)
        }
    }

    /// Pauses the playback. Has no effect when already paused or idle.
    public func pause() {
        player.pause()
    }

    /// Resumes the playback from the current position. Has no effect when not
    /// paused.
    public func resume() {
        player.resume()
    }

    /// Skips to the next audio segment.
    public func skipForward() {
        Task { await goForward() }
    }

    /// Skips to the previous audio segment.
    public func skipBackward() {
        Task { await goBackward() }
    }

    /// Advances to the next segment, or to the first segment of the next clip.
    public func goForward() async {
        if player.skipToNextSegment() {
            log(.debug, "goForward(): skipped to next segment")
            return
        }
        guard let clip = await sequencer.next() else {
            log(.debug, "goForward(): reached end of publication")
            return
        }
        log(.debug, "goForward(): loading next clip \(clip.clip.link.href)")
        load(clip, startAt: 0)
    }

    /// Retreats to the previous segment, or to the last segment of the previous clip.
    public func goBackward() async {
        if player.skipToPreviousSegment() {
            log(.debug, "goBackward(): skipped to previous segment")
            return
        }
        guard let clip = await sequencer.previous() else {
            log(.debug, "goBackward(): reached beginning of publication")
            return
        }
        log(.debug, "goBackward(): loading previous clip \(clip.clip.link.href)")
        load(clip, startAt: clip.nodes.count - 1)
    }

    /// Skips to the first segment of the next reading-order resource.
    public func goToNextResource() async {
//        guard let clip = await sequencer.skipToNextResource() else {
//            log(.debug, "goToNextResource(): already at the last resource")
//            return
//        }
//        log(.debug, "goToNextResource(): loading \(clip.clip.link.href)")
//        load(clip, startAt: 0)
    }

    /// Skips to the first segment of the previous reading-order resource.
    public func goToPreviousResource() async {
//        guard let clip = await sequencer.skipToPreviousResource() else {
//            log(.debug, "goToPreviousResource(): already at the first resource")
//            return
//        }
//        log(.debug, "goToPreviousResource(): loading \(clip.clip.link.href)")
//        load(clip, startAt: 0)
    }

    // MARK: - Private helpers

    /// Loads and starts playing `guidedClip` from the given segment `index`.
    private func load(_ guidedClip: GuidedAudioClip, startAt index: Int) {
        log(.debug, "load(_:startAt:) href=\(guidedClip.clip.link.href) segmentIndex=\(index)/\(guidedClip.clip.segments.count - 1)")
        currentClip = guidedClip
        currentNodeIndex = index
        cumulativeElapsed = guidedClip.clip.computeCumulativeElapsed()
        player.play(guidedClip.clip)
        player.seek(to: guidedClip.clip.segments[index].start)
    }

    /// Extracts the reference from a `ReferenceLocation` existential.
    ///
    /// Swift cannot directly access an associated-type property on `any Protocol`;
    /// this generic trampoline opens the existential implicitly.
    private func extractReference<L: ReferenceLocation>(from location: L) -> (any Reference)? {
        location.reference
    }
}

extension GuidedAudioNavigator: AudioClipPlayerDelegate {
    public func audioClipPlayer(_ player: any AudioClipPlayer, resourceFor link: Link) throws -> any Resource {
        guard let resource = publication.get(link) else {
            throw DebugError("Requested link was not found in the publication: \(link.href)")
        }
        return resource
    }

    public func audioClipPlayer(_ player: any AudioClipPlayer, willStartSegmentAt index: Int, in clip: AudioClip) {
        log(.debug, "willStartSegmentAt \(index)/\(clip.segments.count - 1) in \(clip.link.href)")
        currentNodeIndex = index
        guard let currentClip, index < currentClip.nodes.count else { return }
        let node = currentClip.nodes[index]
        guard let audioRef = node.object.refs?.audio else { return }
        let location = AudioLocation(
            progression: 0, // TODO: compute once publication-duration tracking is added
            temporal: audioRef.temporal,
            reference: audioRef
        )
        delegate?.navigator(self, didChangeLocation: location)
    }

    public func audioClipPlayer(_ player: any AudioClipPlayer, didFinishSegmentAt index: Int, in clip: AudioClip) {
        log(.debug, "didFinishSegmentAt \(index)/\(clip.segments.count - 1) in \(clip.link.href)")
    }

    public func audioClipPlayer(_ player: any AudioClipPlayer, didFinishPlaying clip: AudioClip) {
        log(.debug, "didFinishPlaying \(clip.link.href)")
        Task {
            guard let next = await sequencer.next() else {
                log(.debug, "didFinishPlaying: end of publication reached")
                return
            }
            log(.debug, "didFinishPlaying: auto-advancing to \(next.clip.link.href)")
            currentClip = next
            currentNodeIndex = 0
            cumulativeElapsed = next.clip.computeCumulativeElapsed()
            player.play(next.clip)
        }
    }

    public func audioClipPlayer(_ player: any AudioClipPlayer, didChangeStatus status: AudioClipPlayerStatus) {
        log(.debug, "didChangeStatus \(status)")
        delegate?.navigator(self, didChangeStatus: self.status)
    }

    public func audioClipPlayer(_ player: any AudioClipPlayer, didFailPlaying clip: AudioClip, withError error: any Error) {
        log(.error, "didFailPlaying \(clip.link.href): \(error)")
        delegate?.navigator(self, didFailWithError: error)
    }
}
