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
    case auto = "auto"
    case landscape = "landscape"
    case portrait = "portrait"
}

/// The rendition spread property of an EPUB publication
///
/// - Auto:
/// - Landscape:
/// - Portrait:
/// - Both:
/// - None:
// TODO: remove caps.
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

    required public init?(map: Map) {}

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
