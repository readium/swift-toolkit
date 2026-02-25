//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@preconcurrency import ReadiumShared

/// A ``PlaybackCursor`` driven by pre-authored Guided Navigation Documents
/// (e.g. SMIL for EPUB, JSON for RWPM).
///
/// Fetches ``GuidedNavigationDocument`` objects per reading-order resource and
/// converts them to flat ``PlaybackItem`` sequences.
public struct GuidedNavigationCursor: PlaybackCursor, Sendable, Loggable {
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

    public mutating func next() async -> PlaybackItem? {
        while true {
            guard let items = await currentItems() else {
                return nil
            }

            if cursorIndex < items.count {
                let item = items[cursorIndex]
                cursorIndex += 1
                return item
            }

            // Past the end of the current resource — advance to next.
            resourceIndex += 1
            if resourceIndex >= publication.readingOrder.count {
                return nil
            }
            cursorIndex = 0
        }
    }

    public mutating func previous() async -> PlaybackItem? {
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
    public mutating func seek(to reference: any Reference) async -> Bool {
        guard let ref = reference as? any ResourceReference else {
            return false
        }

        // Find the reading-order resource whose URL matches the reference href.
        guard let targetIndex = publication.readingOrder.firstIndex(where: {
            $0.url().isEquivalentTo(ref.href)
        }) else {
            return false
        }

        // Case 1 – unrefined reference: seek to the start of the resource's GND.
        if !ref.isRefined {
            resourceIndex = targetIndex
            cursorIndex = 0
            return true
        }

        // Case 2 – WebReference with an HTML ID: find the first item whose
        // textAlternate has a CSS selector with a matching HTML ID.
        if let webRef = ref as? WebReference,
           let targetID = webRef.cssSelector?.htmlID
        {
            guard let items = await loadedItems(at: targetIndex) else {
                return false
            }
            guard let itemIndex = items.firstIndex(where: { item in
                guard let alt = item.textAlternate as? WebReference,
                      let altID = alt.cssSelector?.htmlID
                else { return false }
                return altID == targetID
            }) else {
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
    private mutating func currentItems() async -> [PlaybackItem]? {
        await loadedItems(at: resourceIndex)
    }

    /// Returns the cached (or freshly fetched) items for a resource index, or
    /// `nil` if the index is out of bounds.
    ///
    /// Fetch errors are logged and return an empty array so the caller can skip
    /// past the failing resource. Failures are intentionally not cached so that
    /// transient errors can be retried on the next traversal.
    private mutating func loadedItems(at index: Int) async -> [PlaybackItem]? {
        guard publication.readingOrder.indices.contains(index) else {
            return nil
        }

        if let cached = cachedItems[index] {
            return cached
        }

        let link = publication.readingOrder[index]
        let result = await publication.guidedNavigationDocument(for: link.url())

        switch result {
        case let .success(document):
            let items: [PlaybackItem]
            if let document {
                items = makeItems(from: document.guided)
            } else {
                items = []
            }
            cachedItems[index] = items
            return items

        case let .failure(error):
            // Log but do not cache so the fetch can be retried on next traversal.
            log(.error, "Failed to fetch guided navigation document for \(link.href): \(error)")
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

        if let audioURL = object.refs?.audio {
            content = .audio(
                AudioReference(
                    href: audioURL.removingFragment(),
                    temporal: audioURL.fragment?.temporalSelector
                )
            )

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
            // Only refs.text with no inline text or audio — not playable at
            // cursor level.
            return nil
        }

        return PlaybackItem(
            content: content,
            roles: object.roles,
            enclosingRoles: enclosingRoles,
            text: object.text?.plain,
            textAlternate: makeTextAlternate(from: object.refs?.text),
            imageAlternate: makeImageAlternate(from: object.refs?.img)
        )
    }

    private func makeTextAlternate(from url: AnyURL?) -> (any ResourceReference)? {
        guard let url else { return nil }
        return WebReference(
            href: url.removingFragment(),
            text: url.fragment?.textSelector,
            cssSelector: url.fragment?.cssSelector
        )
    }

    private func makeImageAlternate(from url: AnyURL?) -> (any ResourceReference)? {
        guard let url else { return nil }
        return ImageReference(
            href: url.removingFragment(),
            spatial: url.fragment?.spatialSelector
        )
    }
}
