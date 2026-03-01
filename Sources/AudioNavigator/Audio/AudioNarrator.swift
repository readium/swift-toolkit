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

    /// An item that was already fetched from the delegate (because it belongs
    /// to this narrator) but not yet used as the start of a batch. Set by
    /// `play(from:)` and consumed at the top of `startNextBatch()`.
    private var nextBatchStart: PlaybackItem?

    /// The last item passed to `nextItemAfter:`, used to chain delegate calls
    /// so the delegate knows which item to advance past.
    private var lastRequestedItem: PlaybackItem?

    /// Items in the currently playing batch, in playback order. Each item
    /// corresponds to a time range within the single audio clip being played.
    private var activeItems: [PlaybackItem] = []

    /// Index into `activeItems` for the item currently being narrated.
    private var activeIndex: Int = 0

    public init(publication: Publication, player: any AudioClipPlayer) {
        self.publication = publication
        self.player = player
        player.delegate = self
    }

    // MARK: - Narrator

    public func supports(_ item: PlaybackItem) -> Bool {
        if case .audio = item.content { return true }
        return false
    }

    public func play(from item: PlaybackItem) {
        print("[AudioNarrator] play(from:) called with item: \(item)")
        nextBatchStart = item
        lastRequestedItem = nil
        Task { [weak self] in
            await self?.startNextBatch()
        }
    }

    public func pause() {
        player.pause()
    }

    public func resume() {
        player.resume()
    }

    public func stop() {
        player.stop()
        activeItems = []
        activeIndex = 0
        nextBatchStart = nil
    }

    // MARK: - Within-batch navigation

    public func goForward() -> Bool {
        guard activeIndex + 1 < activeItems.count else { return false }
        activeIndex += 1
        let item = activeItems[activeIndex]
        if case let .audio(ref) = item.content {
            let (start, _) = times(for: ref.temporal)
            player.seek(to: start)
        }
        delegate?.narrator(self, didActivateItem: item)
        return true
    }

    public func goBackward() -> Bool {
        guard activeIndex > 0 else { return false }
        activeIndex -= 1
        let item = activeItems[activeIndex]
        if case let .audio(ref) = item.content {
            let (start, _) = times(for: ref.temporal)
            player.seek(to: start)
        }
        delegate?.narrator(self, didActivateItem: item)
        return true
    }

    // MARK: - Batch loading

    /// Loads the next group of consecutive items that all reference the same
    /// audio resource, assembles them into a single ``AudioClip`` with per-item
    /// markers, and starts playing it.
    ///
    /// A "batch" is the unit of work for one `player.play(_:)` call. All items
    /// in the batch share the same audio file; item boundaries within the batch
    /// are communicated to the player as time markers so it can fire
    /// ``AudioClipPlayerDelegate/audioClipPlayer(_:didReachMarker:)`` callbacks
    /// instead of stopping and restarting the file.
    private func startNextBatch() async {
        print("[AudioNarrator] startNextBatch() — nextBatchStart=\(nextBatchStart.map { "\($0)" } ?? "nil")")

        // Use a pre-fetched item if available, otherwise ask the delegate.
        let firstItem: PlaybackItem?
        if let pending = nextBatchStart {
            nextBatchStart = nil
            firstItem = pending
            lastRequestedItem = pending
        } else {
            firstItem = await delegate?.narrator(self, nextItemAfter: lastRequestedItem)
            lastRequestedItem = firstItem
        }

        guard let first = firstItem else {
            print("[AudioNarrator] startNextBatch() — no first item, firing narratorDidFinish")
            delegate?.narratorDidFinish(self)
            return
        }

        guard case let .audio(firstRef) = first.content else {
            // Non-audio items are not supported by this narrator; return nil to
            // the delegate so the navigator can route them elsewhere.
            print("[AudioNarrator] startNextBatch() — first item is not audio, skipping: \(first)")
            lastRequestedItem = first
            await startNextBatch()
            return
        }

        print("[AudioNarrator] startNextBatch() — batch href: \(firstRef.href)")
        let batchHref = firstRef.href
        var batch: [PlaybackItem] = [first]

        // Accumulate consecutive items that share the same audio resource.
        // When the resource changes (or a non-audio item arrives), stash the
        // item as `nextBatchStart` and end accumulation so the next call to
        // `startNextBatch()` picks up where we left off.
        while true {
            let next = await delegate?.narrator(self, nextItemAfter: lastRequestedItem)
            lastRequestedItem = next

            guard let next else {
                print("[AudioNarrator] startNextBatch() — delegate returned nil during batch accumulation, batch size=\(batch.count)")
                break
            }

            guard case let .audio(ref) = next.content, ref.href.isEquivalentTo(batchHref) else {
                print("[AudioNarrator] startNextBatch() — different resource or non-audio, ending batch at size=\(batch.count), holding: \(next)")
                nextBatchStart = next
                break
            }

            batch.append(next)
        }

        // Build the clip spanning the batch.
        // The clip starts at the first item's start time and ends at the last
        // item's end time, so the player plays the full range in one shot.
        let link = publication.linkWithHREF(batchHref) ?? Link(href: batchHref.string)
        let firstTemporal: TemporalSelector? = {
            if case let .audio(r) = batch.first?.content { return r.temporal }
            return nil
        }()
        let lastTemporal: TemporalSelector? = {
            if case let .audio(r) = batch.last?.content { return r.temporal }
            return nil
        }()
        let (clipStart, _) = times(for: firstTemporal)
        let (_, clipEnd) = times(for: lastTemporal)

        // Markers at the start of items[1...] within the batch.
        // The player fires `didReachMarker` at each marker time so we can
        // update `activeIndex` and notify the delegate without restarting playback.
        let markers: [AudioClip.Marker] = batch.dropFirst().compactMap { item in
            guard case let .audio(ref) = item.content else { return nil }
            let (start, _) = times(for: ref.temporal)
            return AudioClip.Marker(time: start)
        }

        let clip = AudioClip(link: link, start: clipStart, end: clipEnd, markers: markers)
        print("[AudioNarrator] startNextBatch() — playing clip: link=\(link.href) start=\(clipStart) end=\(clipEnd.map { "\($0)" } ?? "nil") markers=\(markers.count) batchSize=\(batch.count)")
        print("[AudioNarrator] startNextBatch() — link found in publication: \(publication.linkWithHREF(batchHref) != nil)")

        activeItems = batch
        activeIndex = 0
        delegate?.narrator(self, didActivateItem: batch[0])
        player.play(clip)
    }

    // MARK: - Helpers

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
        // Markers correspond to items[1...] — find by matching marker time to batch start times.
        for (index, item) in activeItems.dropFirst().enumerated() {
            guard case let .audio(ref) = item.content else { continue }
            let (start, _) = times(for: ref.temporal)
            if abs(start - marker.time) < 0.001 {
                activeIndex = index + 1
                delegate?.narrator(self, didActivateItem: activeItems[activeIndex])
                return
            }
        }
    }

    public func audioClipPlayer(_ player: any AudioClipPlayer, didFinishPlaying clip: AudioClip) {
        print("[AudioNarrator] didFinishPlaying: \(clip.link.href)")
        Task { [weak self] in
            await self?.startNextBatch()
        }
    }

    public func audioClipPlayer(_ player: any AudioClipPlayer, didFailPlaying clip: AudioClip, withError error: Error) {
        print("[AudioNarrator] didFailPlaying: \(clip.link.href) error: \(error)")
        delegate?.narrator(self, didFailWithError: error)
    }

    public func audioClipPlayer(_ player: any AudioClipPlayer, didUpdateTime time: TimeInterval) {}

    public func audioClipPlayer(_ player: any AudioClipPlayer, didChangeStatus status: AudioClipPlayerStatus) {
        print("[AudioNarrator] didChangeStatus: \(status)")
    }
}

// MARK: - Errors

public enum AudioNarratorError: Error {
    case resourceNotFound(Link)
}
