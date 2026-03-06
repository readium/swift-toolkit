//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A reference to a ``GuidedNavigationObject`` and its ancestors in the tree.
public struct GuidedNavigationNode {
    /// The referenced object.
    public let object: GuidedNavigationObject

    /// Ancestors from the root down to the parent of ``object``.
    public let ancestors: [GuidedNavigationObject]
}

/// Bidirectional iterator over ``GuidedNavigationObject`` nodes.
///
/// The cursor starts before the first node. Call ``next()`` to advance to it.
public protocol GuidedNavigationCursor: AnyObject {
    /// Returns the next node, or `nil` at the end.
    func next() -> GuidedNavigationNode?

    /// Returns the previous node, or `nil` at the beginning.
    func previous() -> GuidedNavigationNode?

    /// Repositions the cursor so that the next call to ``next()`` returns the
    /// node matching the given ``reference``.
    ///
    /// - Returns: Whether the reference could be resolved.
    @discardableResult
    func seek(to reference: any Reference) -> Bool
}
