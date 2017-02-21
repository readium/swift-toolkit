//
//  Rendition.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/17/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import ObjectMapper

/// The rendition layout property of an EPUB publication
///
/// - Reflowable: not pre-paginated, apply dynamic pagination when rendering
/// - Prepaginated: pre-paginated, one page per spine item
public enum RenditionLayout: String {
    case Reflowable = "reflowable"
    case Prepaginated = "pre-paginated"
}

/// The rendition flow property of an EPUB publication
///
/// - Paginated:
/// - Continuous:
/// - Document:
/// - Fixed:
public enum RenditionFlow: String {
    case Paginated = "paginated"
    case Continuous = "continuous"
    case Document = "document"
    case Fixed = "fixed"
}

/// The rendition orientation property of an EPUB publication
///
/// - Auto:
/// - Landscape:
/// - Portrait:
public enum RenditionOrientation: String {
    case Auto = "auto"
    case Landscape = "landscape"
    case Portrait = "portrait"
}

/// The rendition spread property of an EPUB publication
///
/// - Auto:
/// - Landscape:
/// - Portrait:
/// - Both:
/// - None:
public enum RenditionSpread: String {
    case Auto = "auto"
    case Landscape = "landscape"
    case Portrait = "portrait"
    case Both = "both"
    case None = "none"
}

/// The information relative to the rendering of the publication.
/// It includes if it's reflowable or pre-paginated, the orientation, the synthetic spread
/// behaviour and if the content flow should be scrolled, continuous or paginated.
open class Rendition: Mappable {

    /// The rendition layout (reflowable or pre-paginated)
    public var layout: RenditionLayout?

    /// The rendition flow
    public var flow: RenditionFlow?

    /// The rendition orientation
    public var orientation: RenditionOrientation?

    /// The synthetic spread behaviour
    public var spread: RenditionSpread?

    /// The rendering viewport size
    public var viewport: String?

    public init() {}

    required public init?(map: Map) {
        // TODO: init
    }

    open func mapping(map: Map) {
        layout <- map["layout"]
        flow <- map["flow"]
        orientation <- map["orientation"]
        spread <- map["spread"]
        viewport <- map["viewport"]
    }
}
