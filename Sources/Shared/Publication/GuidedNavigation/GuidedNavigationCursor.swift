//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Navigates across all ``GuidedNavigationDocument`` objects in a publication
/// as a single linear sequence of ``GuidedNavigationNode``.
///
/// The cursor starts *before* the first node. Call ``next()`` to advance to
/// the first node. ``previous()`` retreats one node and returns it, so
/// alternating ``next()`` / ``previous()`` always returns the same node.
/// Both methods cross GND boundaries transparently.
public final class GuidedNavigationCursor {
    /// Guided Navigation Documents order.
    ///
    /// GNDs do not follow the publication reading order one-to-one. A single
    /// GND can cover multiple spine items (e.g. a SMIL document spanning two
    /// pages), and some spine items may have no GND at all.
    ///
    /// This cursor builds a GND order by traversing the publication reading
    /// order and collecting unique GND HREFs into an ordered set. Reading order
    /// items with no GND are skipped; repeated references to the same GND are
    /// deduplicated.
    private let gndOrder: [AnyURL]

    /// Current index in the `gndOrder`.
    ///
    /// -1 = before start, gndOrder.count = after end.
    private var gndIndex: Int = -1

    /// Publication reading order, provided at construction.
    private let readingOrder: [AnyURL]

    /// Maps reading order HREF strings to their index in `gndOrder`.
    private let readingOrderToGndOrderIndex: [AnyURL: Int]

    /// Source of GND HREFs and ``GuidedNavigationDocument`` objects.
    private let provider: any GuidedNavigationDocumentProvider

    /// Cursor over the nodes of the currently active GND.
    ///
    /// `nil` when the overall cursor is positioned before the first document or
    /// after the last document.
    private var documentCursor: GuidedNavigationDocumentCursor?

    /// Last node returned by ``next()`` or ``previous()``, nil before the
    /// first call or after exhaustion.
    private var lastNode: GuidedNavigationNode?

    /// Creates a cursor over the given reading order and document provider.
    ///
    /// - Parameters:
    ///   - readingOrder: Reading order used to derive the GND order.
    ///   - provider: Source of GND HREFs and documents.
    public init(
        readingOrder: [AnyURL],
        provider: any GuidedNavigationDocumentProvider
    ) {
        let readingOrder = readingOrder.map(\.normalized)
        self.readingOrder = readingOrder
        self.provider = provider

        var gndOrder: [AnyURL] = []
        var gndHREFToIndex: [AnyURL: Int] = [:]
        var readingOrderToGndOrderIndex: [AnyURL: Int] = [:]

        for roHREF in readingOrder {
            guard let gndHREF = provider.guidedNavigationDocumentHREF(for: roHREF)?.normalized else {
                continue
            }
            let gnIdx: Int
            if let existing = gndHREFToIndex[gndHREF] {
                gnIdx = existing
            } else {
                gnIdx = gndOrder.count
                gndOrder.append(gndHREF)
                gndHREFToIndex[gndHREF] = gnIdx
            }
            readingOrderToGndOrderIndex[roHREF] = gnIdx
        }

        self.gndOrder = gndOrder
        self.readingOrderToGndOrderIndex = readingOrderToGndOrderIndex
    }

    /// Creates a cursor that navigates a publication's GNDs.
    ///
    /// - Parameters:
    ///   - publication: The publication to navigate.
    ///   - readingOrder: Reading order used to derive the GND order. Defaults
    ///     to ``Publication/readingOrder``.
    /// - Returns: `nil` if the publication has no associated GNDs.
    public convenience init?(
        publication: Publication,
        readingOrder: [AnyURL]? = nil
    ) {
        guard
            let service = publication.findService(GuidedNavigationService.self),
            service.hasGuidedNavigation
        else {
            return nil
        }

        self.init(
            readingOrder: readingOrder ?? publication.readingOrder.map(\.anyURL),
            provider: service
        )
    }

    /// Returns whether the given publication reading order resource is covered
    /// by any pre-authored GND.
    ///
    /// Useful for deciding whether to offer "read aloud" for the resource the
    /// user is currently viewing.
    public func hasGuidedNavigation(for readingOrderHREF: AnyURL) -> Bool {
        readingOrderToGndOrderIndex[readingOrderHREF.normalized] != nil
    }

    // MARK: - Navigation

    /// Returns the next node in the Guided Navigation Document order, or `nil`
    /// at the end.
    public func next() async -> GuidedNavigationNode? {
        if gndIndex == -1 {
            gndIndex = 0
            documentCursor = await loadDocumentCursor(at: 0)
        }

        while gndIndex < gndOrder.count {
            if let node = documentCursor?.next() {
                lastNode = node
                return node
            }
            gndIndex += 1
            documentCursor = await loadDocumentCursor(at: gndIndex)
        }

        lastNode = nil
        return nil
    }

    /// Returns the previous node in the Guided Navigation Document order, or
    /// `nil` at the beginning.
    ///
    /// Alternating `next()` and `previous()` always returns the same node.
    public func previous() async -> GuidedNavigationNode? {
        guard gndIndex >= 0 else {
            return nil
        }

        if gndIndex >= gndOrder.count {
            gndIndex = gndOrder.count - 1
            documentCursor = await loadDocumentCursor(at: gndIndex)
            documentCursor?.seekToEnd()
        }

        while gndIndex >= 0 {
            if let node = documentCursor?.previous() {
                lastNode = node
                return node
            }

            gndIndex -= 1
            documentCursor = await loadDocumentCursor(at: gndIndex)
            documentCursor?.seekToEnd()
        }

        lastNode = nil
        return nil
    }

    /// Repositions the cursor to the node matching `reference` in the
    /// publication reading order resources.
    ///
    /// If the reference cannot be resolved the cursor state is left unchanged
    /// and the method returns `false`.
    @discardableResult
    public func seek(to reference: any Reference) async -> Bool {
        guard
            let targetIndex = readingOrderToGndOrderIndex[reference.href],
            let cursor = await loadDocumentCursor(at: targetIndex),
            cursor.seek(to: reference)
        else {
            return false
        }

        gndIndex = targetIndex
        documentCursor = cursor
        return true
    }

    /// Whether the cursor can skip to the previous Guided Navigation Document.
    public var canSkipToPreviousResource: Bool {
        lastNode != nil && gndIndex > 0
    }

    /// Retreats the cursor to the first node that references a different
    /// publication reading order resource than the node at the current
    /// position, scanning backward through the GND node sequence.
    public func skipToPreviousResource() async {
        guard
            let last = lastNode,
            let current = readingOrderHREF(of: last.object)
        else {
            return
        }

        // Phase 1: go backward until a different resource is found.
        var prev: AnyURL? = nil
        while let node = await previous() {
            if
                let href = readingOrderHREF(of: node.object),
                !current.isEquivalentTo(href)
            {
                prev = href
                break
            }
        }
        guard let prev else {
            return
        }

        // Phase 2: keep going backward within prevRes to find its first node.
        while let node = await previous() {
            if
                let href = readingOrderHREF(of: node.object),
                !prev.isEquivalentTo(href)
            {
                _ = await next() // overshot — restore forward by one
                return
            }
        }
    }

    /// Whether the cursor can skip to the next Guided Navigation Document.
    public var canSkipToNextResource: Bool {
        lastNode != nil && gndIndex < gndOrder.count - 1
    }

    /// Advances the cursor to the first node that references a different
    /// publication reading order resource than the node at the current
    /// position.
    public func skipToNextResource() async {
        guard
            let last = lastNode,
            let current = readingOrderHREF(of: last.object)
        else {
            return
        }

        while let node = await next() {
            if
                let href = readingOrderHREF(of: node.object),
                !current.isEquivalentTo(href)
            {
                _ = await previous() // step back so next() re-returns this node
                return
            }
        }

        // reached end — stay exhausted
    }

    // MARK: - Helpers

    /// Returns the reading order resource HREF for `object`.
    private func readingOrderHREF(of object: GuidedNavigationObject) -> AnyURL? {
        readingOrder.firstMemberFrom(
            object.refs?.text?.href,
            object.refs?.image?.href,
            object.refs?.audio?.href
        )
    }

    /// Loads the GND document at `index` and returns a fresh document cursor.
    private func loadDocumentCursor(at index: Int) async -> GuidedNavigationDocumentCursor? {
        guard
            gndOrder.indices.contains(index),
            let doc = try? await provider.guidedNavigationDocument(at: gndOrder[index])
        else {
            return nil
        }
        return GuidedNavigationDocumentCursor(document: doc)
    }
}
