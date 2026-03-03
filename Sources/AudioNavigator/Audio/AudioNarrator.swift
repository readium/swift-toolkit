//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@preconcurrency import ReadiumShared

/// A ``Narrator`` that plays audio clips using an ``AudioClipPlayer``.
@MainActor
public final class AudioNarrator: Narrator {
    public weak var delegate: (any NarratorDelegate)?

    private let publication: Publication
    private let player: any AudioClipPlayer

    /// The currently executing batch-loading task. Cancelled and replaced
    /// whenever `play(from:)` or `stop()` is called, so that an in-flight
    /// `startNextBatch` cannot overwrite state belonging to a newer playback
    /// session.
    private var batchTask: Task<Void, Never>?

    /// Items in the currently playing batch, in playback order. Each item
    /// corresponds to a time range within the single audio clip being played.
    private var activeItems: [PlaybackItem] = []

    /// Index into `activeItems` for the item currently being narrated.
    private var activeIndex: Int = 0

    /// Maps each `AudioClip.Marker` UUID to the index of the corresponding
    /// item in `activeItems`. Built when a new batch starts and used in
    /// `didReachMarker` to avoid fragile floating-point time comparisons.
    private var markerBatchIndices: [UUID: Int] = [:]

    public init(publication: Publication, player: any AudioClipPlayer) {
        self.publication = publication
        self.player = player
        player.delegate = self
    }

    // MARK: - Narrator

    public var status: NarratorStatus {
        switch player.status {
        case .idle: .idle
        case .loading: .loading
        case .playing: .playing
        case .paused: .paused
        }
    }

    public func addPeriodicTimeObserver(forInterval interval: TimeInterval, using block: @escaping () -> Void) -> Any {
        player.addPeriodicTimeObserver(forInterval: interval, using: block)
    }

    public func time(in scope: TimeScope) -> TimeInterval? {
        nil
    }

    public func duration(of scope: TimeScope) -> TimeInterval? {
        nil
    }

    public func supports(_ item: PlaybackItem) -> Bool {
        if case .audio = item.content { return true }
        return false
    }

    /// Starts narrating from `item`, cancelling any in-flight batch task and
    /// stopping the player first so stale delegate callbacks cannot fire.
    public func play(from item: PlaybackItem) {
        precondition(supports(item), "AudioNarrator does not support the given item")
        print("[AudioNarrator] play(from:) called with item: \(item)")
        cancelBatch()
        player.stop()

        batchTask = Task { [weak self] in
            await self?.startNextBatch(from: item)
        }
    }

    public func pause() {
        player.pause()
    }

    public func resume() {
        player.resume()
    }

    public func stop() {
        cancelBatch()
        player.stop()
    }

    // MARK: - Within-batch navigation

    public func goForward() -> Bool {
        guard activeIndex + 1 < activeItems.count else { return false }
        activeIndex += 1
        let item = activeItems[activeIndex]
        delegate?.narrator(self, willPlayItem: item)
        if case let .audio(ref) = item.content {
            let (start, _) = times(for: ref.temporal)
            player.seek(to: start)
            if player.status == .paused { player.resume() }
        }
        return true
    }

    public func goBackward() -> Bool {
        guard activeIndex > 0 else { return false }
        activeIndex -= 1
        let item = activeItems[activeIndex]
        delegate?.narrator(self, willPlayItem: item)
        if case let .audio(ref) = item.content {
            let (start, _) = times(for: ref.temporal)
            player.seek(to: start)
            if player.status == .paused { player.resume() }
        }
        return true
    }

    // MARK: - Batch loading

    /// Loads consecutive items from the same audio resource as `firstItem`,
    /// assembles them into a single ``AudioClip`` with per-item markers, and
    /// starts playing it.
    ///
    /// A "batch" is the unit of work for one `player.play(_:)` call. All items
    /// in the batch share the same audio file; item boundaries within the batch
    /// are communicated to the player as time markers so it can fire
    /// ``AudioClipPlayerDelegate/audioClipPlayer(_:didReachMarker:)`` callbacks
    /// instead of stopping and restarting the file.
    ///
    /// When the delegate returns an item from a different resource (or nil),
    /// accumulation stops. The delegate is responsible for stashing that item
    /// so it is not lost (see ``AudioNavigator/narrator(_:nextItemAfter:)``).
    private func startNextBatch(from firstItem: PlaybackItem) async {
        guard case let .audio(firstRef) = firstItem.content else { return }

        print("[AudioNarrator] startNextBatch() — batch href: \(firstRef.href)")
        let batchHref = firstRef.href
        var batch: [PlaybackItem] = [firstItem]
        var batchCursor: PlaybackItem = firstItem
        var prevStart: TimeInterval = {
            let (s, _) = times(for: firstRef.temporal)
            return s
        }()

        // Accumulate consecutive items that share the same audio resource.
        // The navigator's `nextItemAfter` implementation stashes any item
        // whose href differs, so we simply break on nil here.
        while true {
            let next = await delegate?.narrator(self, nextItemAfter: batchCursor)

            guard !Task.isCancelled else { return }

            guard let next else {
                print("[AudioNarrator] startNextBatch() — delegate returned nil during batch accumulation, batch size=\(batch.count)")
                break
            }

            // Guard defensively: navigator already filters different-href items.
            guard case let .audio(ref) = next.content,
                  ref.href.isEquivalentTo(batchHref)
            else {
                print("[AudioNarrator] startNextBatch() — unexpected different resource, ending batch at size=\(batch.count)")
                break
            }

            let (nextStart, _) = times(for: ref.temporal)
            guard nextStart > prevStart else {
                print("[AudioNarrator] startNextBatch() — non-monotonic start time, ending batch at size=\(batch.count)")
                break
            }

            batch.append(next)
            batchCursor = next
            prevStart = nextStart
        }

        // Build the clip spanning the batch.
        // The clip starts at the first item's start time and ends at the last
        // item's end time, so the player plays the full range in one shot.
        let link = publication.linkWithHREF(batchHref) ?? Link(href: batchHref.string)
        let firstTemporal: TemporalSelector? = {
            if case let .audio(r) = batch.first?.content { return r.temporal }
            return nil
        }()
        let (clipStart, _) = times(for: firstTemporal)

        // Markers at the start of items[1...] within the batch.
        // The player fires `didReachMarker` at each marker time so we can
        // update `activeIndex` and notify the delegate without restarting
        // playback. Each marker's UUID is stored in `markerBatchIndices` so
        // `didReachMarker` can identify the corresponding item by ID rather
        // than by floating-point time proximity.
        var newMarkerBatchIndices: [UUID: Int] = [:]
        let markers: [AudioClip.Marker] = batch.dropFirst().enumerated().compactMap { i, item in
            guard case let .audio(ref) = item.content else { return nil }
            let (start, _) = times(for: ref.temporal)
            let marker = AudioClip.Marker(time: start)
            newMarkerBatchIndices[marker.id] = i + 1
            return marker
        }

        let clip = AudioClip(link: link, start: clipStart, end: nil, markers: markers)
        print("[AudioNarrator] startNextBatch() — playing clip: link=\(link.href) start=\(clipStart) end=nil markers=\(markers.count) batchSize=\(batch.count)")
        print("[AudioNarrator] startNextBatch() — link found in publication: \(publication.linkWithHREF(batchHref) != nil)")

        activeItems = batch
        activeIndex = 0
        markerBatchIndices = newMarkerBatchIndices
        delegate?.narrator(self, willPlayItem: batch[0])
        player.play(clip)
    }

    // MARK: - Helpers

    /// Cancels the in-flight batch task and resets all batch-level state.
    private func cancelBatch() {
        batchTask?.cancel()
        batchTask = nil
        activeItems = []
        activeIndex = 0
        markerBatchIndices = [:]
    }

    private func times(for temporal: TemporalSelector?) -> (start: TimeInterval, end: TimeInterval?) {
        switch temporal {
        case let .clip(c): return (c.start ?? 0, c.end)
        case let .position(p): return (p.time, nil)
        case nil: return (0, nil)
        }
    }
}

// MARK: - AudioClipPlayerDelegate

extension AudioNarrator: AudioClipPlayerDelegate {
    public func audioClipPlayer(_ player: any AudioClipPlayer, resourceFor link: Link) throws -> Resource {
        print("[AudioNarrator] resourceFor link: \(link.href)")
        guard let resource = publication.get(link) else {
            print("[AudioNarrator] resourceFor — resource NOT FOUND for \(link.href)")
            throw AudioNarratorError.resourceNotFound(link)
        }
        print("[AudioNarrator] resourceFor — resource found for \(link.href)")
        return resource
    }

    public func audioClipPlayer(_ player: any AudioClipPlayer, didReachMarker marker: AudioClip.Marker) {
        guard let index = markerBatchIndices[marker.id] else { return }
        activeIndex = index
        delegate?.narrator(self, willPlayItem: activeItems[activeIndex])
    }

    public func audioClipPlayer(_ player: any AudioClipPlayer, didFinishPlaying clip: AudioClip) {
        print("[AudioNarrator] didFinishPlaying: \(clip.link.href)")
        delegate?.narratorDidFinish(self)
    }

    public func audioClipPlayer(_ player: any AudioClipPlayer, didFailPlaying clip: AudioClip, withError error: Error) {
        print("[AudioNarrator] didFailPlaying: \(clip.link.href) error: \(error)")
        delegate?.narrator(self, didFailWithError: error)
    }

    public func audioClipPlayer(_ player: any AudioClipPlayer, didChangeStatus status: AudioClipPlayerStatus) {
        print("[AudioNarrator] didChangeStatus: \(status)")
        delegate?.narrator(self, didChangeStatus: self.status)
    }
}

// MARK: - Errors

public enum AudioNarratorError: Error {
    /// The publication does not contain a resource matching the given link.
    case resourceNotFound(Link)
}
