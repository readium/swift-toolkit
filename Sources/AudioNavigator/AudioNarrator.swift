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

    /// The item consumed from the delegate that starts the next clip batch.
    private var nextBatchStart: PlaybackItem?

    /// The last item passed to `nextItemAfter:`, used to chain delegate calls.
    private var lastRequestedItem: PlaybackItem?

    /// Items in the currently playing batch, index-mapped to markers.
    private var activeItems: [PlaybackItem] = []

    public init(publication: Publication, player: any AudioClipPlayer) {
        self.publication = publication
        self.player = player
        player.delegate = self
    }

    // MARK: - Narrator

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
        nextBatchStart = nil
    }

    // MARK: - Batch loading

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

        guard case .audio(let firstRef) = first.content else {
            print("[AudioNarrator] startNextBatch() — first item is not audio, skipping: \(first)")
            lastRequestedItem = first
            await startNextBatch()
            return
        }

        print("[AudioNarrator] startNextBatch() — batch href: \(firstRef.href)")
        let batchHref = firstRef.href
        var batch: [PlaybackItem] = [first]

        // Accumulate consecutive items that share the same audio resource.
        while true {
            let next = await delegate?.narrator(self, nextItemAfter: lastRequestedItem)
            lastRequestedItem = next

            guard let next else {
                print("[AudioNarrator] startNextBatch() — delegate returned nil during batch accumulation, batch size=\(batch.count)")
                break
            }

            guard case .audio(let ref) = next.content, ref.href.isEquivalentTo(batchHref) else {
                print("[AudioNarrator] startNextBatch() — different resource or non-audio, ending batch at size=\(batch.count), holding: \(next)")
                nextBatchStart = next
                break
            }

            batch.append(next)
        }

        // Build the clip spanning the batch.
        let link = publication.linkWithHREF(batchHref) ?? Link(href: batchHref.string)
        let firstTemporal: TemporalSelector? = {
            if case .audio(let r) = batch.first?.content { return r.temporal }
            return nil
        }()
        let lastTemporal: TemporalSelector? = {
            if case .audio(let r) = batch.last?.content { return r.temporal }
            return nil
        }()
        let (clipStart, _) = times(for: firstTemporal)
        let (_, clipEnd) = times(for: lastTemporal)

        // Markers at the start of items[1...] within the batch.
        let markers: [AudioClip.Marker] = batch.dropFirst().compactMap { item in
            guard case .audio(let ref) = item.content else { return nil }
            let (start, _) = times(for: ref.temporal)
            return AudioClip.Marker(time: start)
        }

        let clip = AudioClip(link: link, start: clipStart, end: clipEnd, markers: markers)
        print("[AudioNarrator] startNextBatch() — playing clip: link=\(link.href) start=\(clipStart) end=\(clipEnd.map { "\($0)" } ?? "nil") markers=\(markers.count) batchSize=\(batch.count)")
        print("[AudioNarrator] startNextBatch() — link found in publication: \(publication.linkWithHREF(batchHref) != nil)")

        activeItems = batch
        delegate?.narrator(self, didActivateItem: batch[0])
        player.play(clip)
    }

    // MARK: - Helpers

    private func times(for temporal: TemporalSelector?) -> (start: TimeInterval, end: TimeInterval?) {
        switch temporal {
        case .clip(let c): return (c.start ?? 0, c.end)
        case .position(let p): return (p.time, nil)
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
            guard case .audio(let ref) = item.content else { continue }
            let (start, _) = times(for: ref.temporal)
            if abs(start - marker.time) < 0.001 {
                delegate?.narrator(self, didActivateItem: activeItems[index + 1])
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
