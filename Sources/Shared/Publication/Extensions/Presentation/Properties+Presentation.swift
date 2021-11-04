//
//  Properties+Presentation.swift
//  r2-shared-swift
//
//  Created by Mickaël on 24/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Presentation extensions for link `Properties`.
extension Properties {
    
    /// Specifies whether or not the parts of a linked resource that flow out of the viewport are
    /// clipped.
    public var clipped: Bool? {
        otherProperties["clipped"] as? Bool
    }
    
    /// Suggested method for constraining a resource inside the viewport.
    public var fit: Presentation.Fit? {
        parseRaw(otherProperties["fit"])
    }
    
    /// Suggested orientation for the device when displaying the linked resource.
    public var orientation: Presentation.Orientation? {
        parseRaw(otherProperties["orientation"])
    }
    
    /// Indicates if the overflow of linked resources from the `readingOrder` or `resources` should
    /// be handled using dynamic pagination or scrolling.
    public var overflow: Presentation.Overflow? {
        parseRaw(otherProperties["overflow"])
    }
    
    /// Indicates how the linked resource should be displayed in a reading environment that
    /// displays synthetic spreads.
    public var page: Presentation.Page? {
        parseRaw(otherProperties["page"])
    }
    
    /// Indicates the condition to be met for the linked resource to be rendered within a synthetic
    ///  spread.
    public var spread: Presentation.Spread? {
        parseRaw(otherProperties["spread"])
    }
    
}
