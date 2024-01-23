//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Presentation extensions for link `Properties`.
public extension Properties {
    /// Specifies whether or not the parts of a linked resource that flow out of the viewport are
    /// clipped.
    var clipped: Bool? {
        otherProperties["clipped"] as? Bool
    }

    /// Suggested method for constraining a resource inside the viewport.
    var fit: Presentation.Fit? {
        parseRaw(otherProperties["fit"])
    }

    /// Suggested orientation for the device when displaying the linked resource.
    var orientation: Presentation.Orientation? {
        parseRaw(otherProperties["orientation"])
    }

    /// Indicates if the overflow of linked resources from the `readingOrder` or `resources` should
    /// be handled using dynamic pagination or scrolling.
    var overflow: Presentation.Overflow? {
        parseRaw(otherProperties["overflow"])
    }

    /// Indicates how the linked resource should be displayed in a reading environment that
    /// displays synthetic spreads.
    var page: Presentation.Page? {
        parseRaw(otherProperties["page"])
    }

    /// Indicates the condition to be met for the linked resource to be rendered within a synthetic
    ///  spread.
    var spread: Presentation.Spread? {
        parseRaw(otherProperties["spread"])
    }
}
