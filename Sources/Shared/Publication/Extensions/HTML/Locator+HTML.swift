//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// HTML extensions for `Locator.Locations`.
/// https://github.com/readium/architecture/blob/master/models/locators/extensions/html.md
public extension Locator.Locations {
    /// A CSS Selector.
    var cssSelector: String? {
        otherLocations["cssSelector"] as? String
    }

    /// `partialCFI` is an expression conforming to the "right-hand" side of the EPUB CFI syntax,
    /// that is to say: without the EPUB-specific OPF spine item reference that precedes the first !
    /// exclamation mark (which denotes the "step indirection" into a publication document). Note
    /// that the wrapping `epubcfi(***)` syntax is not used for the `partialCFI` string, i.e.
    /// the "fragment" part of the CFI grammar is ignored.
    var partialCFI: String? {
        otherLocations["partialCfi"] as? String
    }

    /// An HTML DOM range.
    var domRange: DOMRange? {
        try? DOMRange(json: otherLocations["domRange"], warnings: self)
    }
}
