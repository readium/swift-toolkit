//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A lazy, bidirectional iterator over a playback sequence.
///
/// `next()` returns the item to the right of the cursor and advances it
/// rightward. `previous()` retreats the cursor leftward and returns the
/// item now to the right. This means alternating `next()` / `previous()`
/// always re-returns the same item.
@MainActor
public protocol PlaybackCursor: AnyObject {
    /// Returns the next item in the sequence, or `nil` at the end.
    func next() async -> PlaybackItem?

    /// Returns the previous item in the sequence, or `nil` at the beginning.
    func previous() async -> PlaybackItem?

    /// Repositions the cursor to the nearest item at or after the given
    /// ``reference``.
    ///
    /// - Returns: Whether the reference could be resolved.
    @discardableResult
    func seek(to reference: any Reference) async -> Bool
}

/// A ``PlaybackCursor`` driven by pre-authored Guided Navigation Documents
/// (e.g. SMIL for EPUB, JSON for RWPM).
///
/// Fetches ``GuidedNavigationDocument`` objects per reading-order resource and
/// converts them to flat ``PlaybackItem`` sequences.
@MainActor
public final class GuidedNavigationPlaybackCursor: PlaybackCursor, Loggable {
    private let publication: Publication

    /// Current resource within the reading order.
    private var resourceIndex: Int = 0

    /// Cursor index within `currentItems`.
    ///
    /// The cursor index points to a position *between* items.
    /// - `cursorIndex == 0`: before the first item of the current resource.
    /// - `cursorIndex == n`: after the n-th item (0-based) of the current
    ///    resource.
    private var cursorIndex: Int = 0

    public init(publication: Publication) {
        self.publication = publication
    }

    // MARK: - PlaybackCursor

    public func next() async -> PlaybackItem? {
        while true {
            guard let items = await currentItems() else {
                print("[GuidedNavigationPlaybackCursor] next() — currentItems() returned nil (out of bounds), resourceIndex=\(resourceIndex)")
                return nil
            }

            if cursorIndex < items.count {
                let item = items[cursorIndex]
                cursorIndex += 1
                print("[GuidedNavigationPlaybackCursor] next() → item[\(cursorIndex - 1)] of resource[\(resourceIndex)]: \(item)")
                return item
            }

            // Past the end of the current resource — advance to next.
            resourceIndex += 1
            if resourceIndex >= publication.readingOrder.count {
                print("[GuidedNavigationPlaybackCursor] next() — reached end of publication")
                return nil
            }
            cursorIndex = 0
            print("[GuidedNavigationPlaybackCursor] next() — advancing to resource[\(resourceIndex)]")
        }
    }

    public func previous() async -> PlaybackItem? {
        while true {
            if cursorIndex > 0 {
                guard let items = await currentItems() else {
                    return nil
                }
                cursorIndex -= 1
                return items[cursorIndex]
            }

            // Before the start of the current resource — retreat to previous.
            if resourceIndex == 0 {
                return nil
            }
            resourceIndex -= 1
            cursorIndex = await (currentItems() ?? []).count
        }
    }

    @discardableResult
    public func seek(to reference: any Reference) async -> Bool {
        guard
            let targetIndex = publication.readingOrder.firstIndexWithHREF(reference.href)
        else {
            return false
        }

        // Unrefined reference: jump to the start of the resource.
        guard reference.isRefined else {
            resourceIndex = targetIndex
            cursorIndex = 0
            return true
        }

        // Refined WebReference: find the item whose readingOrderReference
        // shares the same HTML ID (e.g. EPUB Media Overlay sync point).
        if let targetID = (reference as? WebReference)?.cssSelector?.htmlID {
            guard
                let items = await loadedItems(at: targetIndex),
                let itemIndex = items.firstIndex(where: {
                    ($0.readingOrderReference as? WebReference)?.cssSelector?.htmlID == targetID
                })
            else {
                return false
            }
            resourceIndex = targetIndex
            cursorIndex = itemIndex
            return true
        }

        return false
    }

    // MARK: - GuidedNavigationDocument Loading

    /// Cached PlaybackItem arrays keyed by resourceIndex.
    ///
    /// Only successful fetches are cached; failures are not, to allow retries
    /// on the next traversal.
    private var cachedItems: [Int: [PlaybackItem]] = [:]

    /// Returns the items for the current cursor position, or `nil` if the
    /// cursor is out of bounds.
    private func currentItems() async -> [PlaybackItem]? {
        await loadedItems(at: resourceIndex)
    }

    /// Returns the cached (or freshly fetched) items for a resource index, or
    /// `nil` if the index is out of bounds.
    ///
    /// Fetch errors are logged and return an empty array so the caller can skip
    /// past the failing resource. Failures are intentionally not cached so that
    /// transient errors can be retried on the next traversal.
    private func loadedItems(at index: Int) async -> [PlaybackItem]? {
        guard publication.readingOrder.indices.contains(index) else {
            return nil
        }

        if let cached = cachedItems[index] {
            return cached
        }

        let link = publication.readingOrder[index]
        print("[GuidedNavigationPlaybackCursor] fetching GND for resource[\(index)]: \(link.href)")
        do {
            guard let gndHREF = publication.guidedNavigationDocumentHREF(for: link.url()) else {
                print("[GuidedNavigationPlaybackCursor] no GND found for \(link.href)")
                cachedItems[index] = []
                return []
            }
            let doc = try await publication.guidedNavigationDocument(at: gndHREF)
            let items = doc.map { makeItems(from: $0.guided) } ?? []
            print("[GuidedNavigationPlaybackCursor] resource[\(index)] \(link.href) → \(items.count) items")

            cachedItems[index] = items
            return items

        } catch {
            // Log but do not cache so the fetch can be retried on next traversal.
            log(.error, "Failed to fetch guided navigation document for \(link.href): \(error)")
            print("[GuidedNavigationPlaybackCursor] ERROR fetching GND for \(link.href): \(error)")
            return []
        }
    }

    // MARK: - GNO → PlaybackItem Conversion

    private func makeItems(from objects: [GuidedNavigationObject], enclosingRoles: [ContentRole] = []) -> [PlaybackItem] {
        objects.flatMap { makeItems(from: $0, enclosingRoles: enclosingRoles) }
    }

    private func makeItems(from object: GuidedNavigationObject, enclosingRoles: [ContentRole]) -> [PlaybackItem] {
        var result: [PlaybackItem] = []

        let isSequence = object.roles.contains(.sequence)
        let hasPlayableContent =
            object.refs?.audio != nil
                || object.text?.plain != nil
                || object.text?.ssml != nil

        if hasPlayableContent, !isSequence {
            if let item = makeItem(from: object, enclosingRoles: enclosingRoles) {
                result.append(item)
            }
        }

        result += makeItems(from: object.children, enclosingRoles: object.roles + enclosingRoles)
        return result
    }

    private func makeItem(
        from object: GuidedNavigationObject,
        enclosingRoles: [ContentRole]
    ) -> PlaybackItem? {
        let content: PlaybackItem.Content

        if let audioRef = object.refs?.audio {
            content = .audio(audioRef)

        } else if
            let gnoText = object.text,
            let textContent = PlaybackItem.Content.Text(
                text: gnoText.plain,
                ssml: gnoText.ssml,
                language: gnoText.language
            )
        {
            content = .text(textContent)

        } else {
            // Only refs.text with no inline text or audio - not playable at
            // cursor level.
            return nil
        }

        let readingOrderReference: (any Reference)?
        if let textRef = object.refs?.text {
            // EPUB with Media Overlays
            readingOrderReference = textRef

        } else if let imgRef = object.refs?.img {
            // Divina with GND
            readingOrderReference = imgRef
        } else if case let .audio(audioRef) = content {
            // Audiobook
            readingOrderReference = audioRef
        } else {
            readingOrderReference = nil
        }

        return PlaybackItem(
            content: content,
            roles: object.roles,
            enclosingRoles: enclosingRoles,
            readingOrderReference: readingOrderReference
        )
    }
}
