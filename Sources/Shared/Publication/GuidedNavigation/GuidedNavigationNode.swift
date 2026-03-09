//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A reference to a ``GuidedNavigationObject`` and its ancestors in the tree.
public struct GuidedNavigationNode {
    public typealias IndexPath = [Int]

    /// Index path in the whole tree.
    ///
    /// Can be used as a unique identifier for this node in the tree.
    public let indexPath: IndexPath

    /// The referenced object.
    public let object: GuidedNavigationObject

    /// Ancestors from the root down to the parent of ``object``.
    public let ancestors: [GuidedNavigationObject]

    /// All enclosing roles in the hierarchy for this node, ordered outermost to
    /// innermost.
    ///
    /// The roles of the `object` itself are included.
    public var enclosingRoles: [ContentRole] {
        ancestors.flatMap(\.roles) + object.roles
    }
}
