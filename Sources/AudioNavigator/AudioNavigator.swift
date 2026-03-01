//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@preconcurrency import ReadiumShared

/// Coordinates audio playback of a publication by pulling ``PlaybackItem``s
/// from a ``GuidedNavigationCursor`` and routing them to the active ``Narrator``.
@MainActor
public final class AudioNavigator {
    /// Event callbacks for the navigator.
    public weak var delegate: (any AudioNavigatorDelegate)?

    /// The last activated ``PlaybackItem`` — the ground truth for the current
    /// playback position.
    public private(set) var currentItem: PlaybackItem?

    /// An item peeked from the cursor that the current narrator does not
    /// support. Returned to the next narrator via `nextItemAfter` rather than
    /// being consumed from the cursor again.
    private var pendingItem: PlaybackItem?

    private let publication: Publication
    private let cursor: GuidedNavigationCursor

    /// Ordered list of narrators tried in turn for each item.
    /// The first narrator that returns `true` from `supports(_:)` wins.
    private let narrators: [any Narrator]

    /// The narrator currently playing (or last played). Only one narrator is
    /// active at a time; switching stops the previous one before starting the new one.
    private var activeNarrator: (any Narrator)?

    public init(publication: Publication, narrators: [any Narrator]) {
        self.publication = publication
        cursor = GuidedNavigationCursor(publication: publication)
        self.narrators = narrators
        // Register self as the delegate for all narrators up front so that
        // whichever narrator becomes active later can already call back into us.
        for narrator in narrators {
            narrator.delegate = self
        }
    }

    /// Returns the first narrator in `narrators` that can handle `item`, or
    /// `nil` if no narrator supports it (the item will be skipped).
    private func narrator(for item: PlaybackItem) -> (any Narrator)? {
        narrators.first { $0.supports(item) }
    }

    // MARK: - Playback control

    public func play() {
        print("[AudioNavigator] play() called")
        Task {
            guard let item = await cursor.next() else {
                print("[AudioNavigator] play() — cursor returned nil, nothing to play")
                return
            }
            print("[AudioNavigator] play() — got first item from cursor: \(item)")
            startNarrating(from: item)
        }
    }

    private func startNarrating(from item: PlaybackItem) {
        guard let narrator = narrator(for: item) else { return }
        pendingItem = nil
        // Stop the previous narrator before switching so its resources are
        // released and it no longer sends delegate callbacks.
        if activeNarrator !== narrator {
            activeNarrator?.stop()
            activeNarrator = narrator
        }
        narrator.play(from: item)
    }

    public func pause() {
        activeNarrator?.pause()
    }

    public func resume() {
        activeNarrator?.resume()
    }

    public func stop() {
        activeNarrator?.stop()
    }

    /// Moves to the next playback item.
    ///
    /// If there is a next item within the current narrator batch, the narrator
    /// handles it directly. Otherwise the navigator stops the narrator, advances
    /// the cursor past the current batch, and starts the next batch.
    public func goForward() async {
        guard !(activeNarrator?.goForward() ?? false) else { return }
        activeNarrator?.stop()
        if let ref = currentItem?.readingOrderReference {
            await cursor.seek(to: ref)
            _ = await cursor.next()
        }
        guard let item = await nextSupportedItem() else { return }
        startNarrating(from: item)
    }

    /// Moves to the previous playback item.
    ///
    /// If there is a previous item within the current narrator batch, the
    /// narrator handles it directly. Otherwise the navigator stops the narrator,
    /// seeks the cursor back to the start of the current batch, and plays the
    /// last item of the previous batch.
    public func goBackward() async {
        guard !(activeNarrator?.goBackward() ?? false) else { return }
        // When the narrator returns false, activeIndex == 0, so `currentItem`
        // is the first item of the batch — seek the cursor back to it before
        // stepping to the previous batch.
        activeNarrator?.stop()
        if let ref = currentItem?.readingOrderReference {
            await cursor.seek(to: ref)
        }
        guard let item = await previousSupportedItem() else { return }
        startNarrating(from: item)
    }

    /// Jumps to the first supported item of the next reading-order resource.
    public func goToNextResource() async {
        guard let nextURL = adjacentResourceURL(offset: +1) else { return }
        activeNarrator?.stop()
        await cursor.seek(to: WebReference(href: nextURL))
        guard let item = await nextSupportedItem() else { return }
        startNarrating(from: item)
    }

    /// Jumps to the first supported item of the previous reading-order resource.
    public func goToPreviousResource() async {
        guard let prevURL = adjacentResourceURL(offset: -1) else { return }
        activeNarrator?.stop()
        await cursor.seek(to: WebReference(href: prevURL))
        guard let item = await nextSupportedItem() else { return }
        startNarrating(from: item)
    }

    /// Returns the URL of the reading-order resource `offset` positions away
    /// from the one containing `currentItem`, or `nil` if out of bounds.
    ///
    /// Uses `currentItem.readingOrderReference.href` to locate the current
    /// resource in the reading order; the base href (fragment stripped) is
    /// compared against each reading-order link URL.
    private func adjacentResourceURL(offset: Int) -> AnyURL? {
        guard
            let currentHref = currentItem?.readingOrderReference?.href,
            let idx = publication.readingOrder.firstIndexWithHREF(currentHref),
            let href = publication.readingOrder.getOrNil(idx + offset)?.url()
        else {
            return nil
        }

        return href
    }

    /// Advances the cursor until it finds an item that at least one narrator
    /// supports, skipping unsupported items silently.
    private func nextSupportedItem() async -> PlaybackItem? {
        while let item = await cursor.next() {
            if narrator(for: item) != nil { return item }
        }
        return nil
    }

    /// Walks the cursor backwards until it finds a supported item. After
    /// returning, the cursor is positioned just after that item so the
    /// narrator's subsequent `nextItemAfter` calls read the items that follow it.
    private func previousSupportedItem() async -> PlaybackItem? {
        while let item = await cursor.previous() {
            if narrator(for: item) != nil {
                // `previous()` leaves the cursor before `item`. Re-advance so
                // the narrator's first `nextItemAfter` call gets the item after
                // `item`, not `item` itself (the narrator receives `item` via
                // `play(from:)`, not through the cursor).
                _ = await cursor.next()
                return item
            }
        }
        return nil
    }
}

// MARK: - NarratorDelegate

extension AudioNavigator: NarratorDelegate {
    public func narrator(_ narrator: any Narrator, nextItemAfter item: PlaybackItem?) async -> PlaybackItem? {
        let next: PlaybackItem
        if let pending = pendingItem {
            // A previous call stored an item that the then-active narrator
            // didn't support. Hand it back now so it isn't lost.
            pendingItem = nil
            next = pending
        } else {
            guard let fetched = await cursor.next() else {
                print("[AudioNavigator] nextItemAfter — cursor exhausted")
                return nil
            }
            next = fetched
        }
        guard narrator.supports(next) else {
            // The item belongs to a different narrator type. Stash it so the
            // navigator can route it to the right narrator after the current
            // batch finishes, rather than consuming it from the cursor again.
            print("[AudioNavigator] nextItemAfter — item not supported by narrator, holding as pending: \(next)")
            pendingItem = next
            return nil
        }
        print("[AudioNavigator] nextItemAfter — returning item: \(next)")
        return next
    }

    public func narrator(_ narrator: any Narrator, didActivateItem item: PlaybackItem) {
        // Ignore stale callbacks from a narrator that was stopped and replaced.
        guard narrator === activeNarrator else { return }
        currentItem = item
        print("[AudioNavigator] didActivateItem: \(item)")
        delegate?.audioNavigator(self, didActivateItem: item)
    }

    public func narratorDidFinish(_ narrator: any Narrator) {
        guard narrator === activeNarrator else { return }
        if let pending = pendingItem {
            // A pending item was stashed because the previous narrator didn't
            // support it. Route it to whichever narrator does (narrator switching).
            startNarrating(from: pending)
        } else {
            delegate?.audioNavigatorDidFinish(self)
        }
    }

    public func narrator(_ narrator: any Narrator, didFailWithError error: Error) {
        guard narrator === activeNarrator else { return }
        delegate?.audioNavigator(self, didFailWithError: error)
    }
}

// MARK: - AudioNavigatorDelegate

@MainActor public protocol AudioNavigatorDelegate: AnyObject {
    func audioNavigator(_ navigator: AudioNavigator, didActivateItem item: PlaybackItem)
    func audioNavigatorDidFinish(_ navigator: AudioNavigator)
    func audioNavigator(_ navigator: AudioNavigator, didFailWithError error: Error)
}
