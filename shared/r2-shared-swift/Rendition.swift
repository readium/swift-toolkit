//
//  Rendition.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/17/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import ObjectMapper

/// The rendition layout property of an EPUB publication
///
/// - Reflowable: Apply dynamic pagination when rendering.
/// - Fixed: Fixed layout.
public enum RenditionLayout: String {
    case reflowable = "reflowable"
    case fixed = "pre-paginated"
}

/// The rendition flow property of an EPUB publication.
///
/// - Paginated: Indicates the Author preference is to dynamically paginate content overflow.
/// - Continuous:Indicates the Author preference is to provide a scrolled view
///              for overflow content, and that consecutive spine items with this
///              property are to be rendered as a continuous scroll.
/// - Document: Indicates the Author preference is to provide a scrolled view for
///             overflow content, and each spine item with this property is to 
///             be rendered as separate scrollable document.
/// - Fixed:
public enum RenditionFlow: String {
    case paginated = "paginated"
    case continuous = "continuous"
    case document = "document"
    case fixed = "fixed" // Is that correct?
}

/// The rendition orientation property of an EPUB publication.
///
/// - Auto: Specifies that the Reading System can determine the orientation to
///         rendered the spine item in.
/// - Landscape: Specifies that the given spine item is to be rendered in
///              landscape orientation.
/// - Portrait: Specifies that the given spine item is to be rendered in portrait
///             orientation.
public enum RenditionOrientation: String {
    case auto = "auto"
    case landscape = "landscape"
    case portrait = "portrait"
}

/// The rendition spread property of an EPUB publication.
///
/// - auto: Specifies the Reading System can determine when to render a synthetic
///         spread for the spine item.
/// - landscape: Specifies the Reading System should render a synthetic spread 
///              for the spine item only when in landscape orientation.
/// - portrait: The spread-portrait property is deprecated in [EPUB3]. Refer to 
///             its definition in [Publications301] for more information.
/// - both: Specifies the Reading System should render a synthetic spread for the
///         spine item in both portrait and landscape orientations.
/// - none: Specifies the Reading System should not render a synthetic spread 
///         for the spine item.
public enum RenditionSpread: String {
    case auto = "auto"
    case landscape = "landscape"
    case portrait = "portrait"
    case both = "both"
    case none = "none"
}

/// The information relative to the rendering of the publication.
/// It includes if it's reflowable or pre-paginated, the orientation, the synthetic spread
/// behaviour and if the content flow should be scrolled, continuous or paginated.
public class Rendition {
    /// The rendition layout (reflowable or fixed).
    public var layout: RenditionLayout?
    /// The rendition flow.
    public var flow: RenditionFlow?
    /// The rendition orientation.
    public var orientation: RenditionOrientation?
    /// The synthetic spread behaviour.
    public var spread: RenditionSpread?
    /// The rendering viewport size.
    public var viewport: String?

    public init() {}

    required public init?(map: Map) {}

    public func isEmpty() -> Bool {
        guard layout != nil || flow != nil
            || orientation != nil || spread != nil
            || viewport != nil else
        {
            return true
        }
        return false
    }

}

extension Rendition: Mappable {
    public func mapping(map: Map) {
        layout <- map["layout", ignoreNil: true]
        flow <- map["flow", ignoreNil: true]
        orientation <- map["orientation", ignoreNil: true]
        spread <- map["spread", ignoreNil: true]
        viewport <- map["viewport", ignoreNil: true]
    }
}
