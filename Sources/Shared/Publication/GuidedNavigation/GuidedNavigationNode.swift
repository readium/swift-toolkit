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
