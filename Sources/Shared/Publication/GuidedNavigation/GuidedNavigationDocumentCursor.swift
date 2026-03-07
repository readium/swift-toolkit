//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Iterates over a single ``GuidedNavigationDocument`` in DFS pre-order.
final class GuidedNavigationDocumentCursor {
    private let root: [GuidedNavigationObject]

    /// The last node returned by `next()`, or nil if before start.
    /// When `next()` exhausts the tree it returns nil without changing this
    /// property, so `previous()` still returns the current node.
    private var current: GuidedNavigationObject?

    /// Zipper breadcrumbs. Each entry records the sibling array and the index
    /// of the node at that depth.
    ///
    /// The ancestors of `current` are `breadcrumbs.dropLast()` mapped to
    /// their respective `siblings[index]`.
    private var breadcrumbs: [(siblings: [GuidedNavigationObject], index: Int)] = []

    init(document: GuidedNavigationDocument) {
        root = document.guided
    }

    // MARK: - Iteration

    /// Returns the next node, or `nil` at the end.
    func next() -> GuidedNavigationNode? {
        guard dfsNext() != nil else { return nil }
        return makeNode()
    }

    /// Returns the previous node, or `nil` at the beginning.
    func previous() -> GuidedNavigationNode? {
        guard current != nil else { return nil }
        let node = makeNode()
        dfsPrev()
        return node
    }

    private func makeNode() -> GuidedNavigationNode? {
        guard let obj = current else { return nil }
        let ancestors = breadcrumbs.dropLast().map { $0.siblings[$0.index] }
        return GuidedNavigationNode(object: obj, ancestors: ancestors)
    }

    /// Advances `current` and `breadcrumbs` to the next node in DFS pre-order
    /// and returns it, or returns `nil` without mutating state if already at
    /// the end.
    private func dfsNext() -> GuidedNavigationObject? {
        guard let last = current else {
            // Before start: move to the first node.
            guard !root.isEmpty else { return nil }
            current = root[0]
            breadcrumbs = [(root, 0)]
            return current
        }

        // Descend into first child.
        if !last.children.isEmpty {
            breadcrumbs.append((last.children, 0))
            current = last.children[0]
            return current
        }

        // Ascend until a next sibling is found.
        let savedBreadcrumbs = breadcrumbs
        while !breadcrumbs.isEmpty {
            let (siblings, idx) = breadcrumbs[breadcrumbs.count - 1]
            if idx + 1 < siblings.count {
                breadcrumbs[breadcrumbs.count - 1] = (siblings, idx + 1)
                current = siblings[idx + 1]
                return current
            }
            breadcrumbs.removeLast()
        }

        // At end — restore breadcrumbs so `previous()` can still navigate back.
        breadcrumbs = savedBreadcrumbs
        return nil
    }

    /// Retreats `current` and `breadcrumbs` to the DFS predecessor of the
    /// current node. Sets `current = nil` when the beginning is reached.
    private func dfsPrev() {
        guard !breadcrumbs.isEmpty else {
            current = nil
            return
        }

        let (siblings, idx) = breadcrumbs[breadcrumbs.count - 1]

        if idx == 0 {
            // The parent node is the predecessor.
            breadcrumbs.removeLast()
            if breadcrumbs.isEmpty {
                current = nil
            } else {
                let (parentSiblings, parentIdx) = breadcrumbs[breadcrumbs.count - 1]
                current = parentSiblings[parentIdx]
            }
        } else {
            // Move to previous sibling, then descend to its last leaf.
            let prevIdx = idx - 1
            breadcrumbs[breadcrumbs.count - 1] = (siblings, prevIdx)
            current = siblings[prevIdx]
            descendToLastLeaf()
        }
    }

    /// Descends into the last child at each level until reaching a leaf,
    /// updating `current` and `breadcrumbs`.
    private func descendToLastLeaf() {
        while let node = current, !node.children.isEmpty {
            let children = node.children
            let lastIdx = children.count - 1
            breadcrumbs.append((children, lastIdx))
            current = children[lastIdx]
        }
    }

    // MARK: - Seeking

    /// Positions the cursor after the last node so that the next call to
    /// ``previous()`` returns the last node in DFS order.
    func seekToEnd() {
        guard !root.isEmpty else { return }
        let lastIdx = root.count - 1
        breadcrumbs = [(root, lastIdx)]
        current = root[lastIdx]
        descendToLastLeaf()
    }

    /// Repositions the cursor so that the next call to ``next()`` returns the
    /// node matching the given ``reference``.
    ///
    /// - Returns: Whether the reference could be resolved.
    @discardableResult
    func seek(to reference: any Reference) -> Bool {
        guard !root.isEmpty else { return false }

        var prev: GuidedNavigationObject? = nil
        var prevBreadcrumbs: [(siblings: [GuidedNavigationObject], index: Int)] = []
        var stack: [(siblings: [GuidedNavigationObject], index: Int)] = [(root, 0)]

        while !stack.isEmpty {
            let (siblings, idx) = stack[stack.count - 1]
            let node = siblings[idx]

            if matches(node: node, reference: reference) {
                current = prev
                breadcrumbs = prevBreadcrumbs
                return true
            }

            prev = node
            prevBreadcrumbs = stack

            // Advance the walk: descend or move to next sibling/uncle.
            if !node.children.isEmpty {
                stack.append((node.children, 0))
            } else {
                var advanced = false
                while !stack.isEmpty {
                    let (sib, i) = stack[stack.count - 1]
                    if i + 1 < sib.count {
                        stack[stack.count - 1] = (sib, i + 1)
                        advanced = true
                        break
                    }
                    stack.removeLast()
                }
                if !advanced { break }
            }
        }

        return false
    }

    /// Returns `true` when `node` matches the given `reference`.
    private func matches(node: GuidedNavigationObject, reference: any Reference) -> Bool {
        return switch reference {
        case let reference as AudioReference:
            matches(node: node, reference: reference)
        case let reference as WebReference:
            matches(node: node, reference: reference)
        case let reference as ImageReference:
            matches(node: node, reference: reference)
        default:
            false
        }
    }

    /// Returns `true` when `node` matches the given `reference`.
    private func matches(node: GuidedNavigationObject, reference: AudioReference) -> Bool {
        guard
            let ref = node.refs?.audio,
            ref.href.string == reference.href.string
        else {
            return false
        }

        if reference.isRefined {
            return ref.temporal == reference.temporal
        }

        return true
    }

    /// Returns `true` when `node` matches the given `reference`.
    private func matches(node: GuidedNavigationObject, reference: WebReference) -> Bool {
        guard
            let ref = node.refs?.text,
            ref.href.string == reference.href.string
        else {
            return false
        }

        if reference.isRefined {
            if let css = reference.cssSelector {
                return ref.cssSelector == css
            }
            if let txt = reference.text {
                return ref.text == txt
            }
            return false
        }

        return true
    }

    /// Returns `true` when `node` matches the given `reference`.
    private func matches(node: GuidedNavigationObject, reference: ImageReference) -> Bool {
        guard
            let ref = node.refs?.img,
            ref.href.string == reference.href.string
        else {
            return false
        }

        if reference.isRefined {
            return ref.spatial == reference.spatial
        }

        return true
    }
}
