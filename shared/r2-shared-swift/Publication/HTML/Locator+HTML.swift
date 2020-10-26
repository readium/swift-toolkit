//
//  Locator+HTML.swift
//  r2-shared-swift
//
//  Created by Mickaël on 25/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// HTML extensions for `Locator.Locations`.
/// https://github.com/readium/architecture/blob/master/models/locators/extensions/html.md
extension Locator.Locations {
    
    /// A CSS Selector.
    public var cssSelector: String? {
        otherLocations["cssSelector"] as? String
    }
    
    /// `partialCFI` is an expression conforming to the "right-hand" side of the EPUB CFI syntax,
    /// that is to say: without the EPUB-specific OPF spine item reference that precedes the first !
    /// exclamation mark (which denotes the "step indirection" into a publication document). Note
    /// that the wrapping `epubcfi(***)` syntax is not used for the `partialCFI` string, i.e.
    /// the "fragment" part of the CFI grammar is ignored.
    public var partialCFI: String? {
        otherLocations["partialCfi"] as? String
    }
    
    /// An HTML DOM range.
    public var domRange: DOMRange? {
        try? DOMRange(json: otherLocations["domRange"], warnings: self)
    }
    
}
