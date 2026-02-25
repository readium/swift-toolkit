//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A reference identifies a specific point or region within a publication.
public protocol Reference: Hashable, Sendable {}

/// A reference pointing to a specific resource within a publication, identified
/// by its URL.
public protocol ResourceReference: Reference {
    /// URL of the resource within the publication.
    var href: AnyURL { get }

    /// Returns `true` when this reference carries location information beyond
    /// the resource URL – i.e. it targets a specific position, range, or region
    /// rather than the start of the resource.
    var isRefined: Bool { get }
}

/// A reference within an HTML/XHTML resource, as used by the EPUB and web-based
/// navigators.
public struct WebReference: ResourceReference {
    /// URL of the HTML/XHTML resource within the publication.
    public var href: AnyURL

    /// Progression within the resource, expressed as a percentage between 0 and
    /// 1.
    public var progression: Progression?

    /// Selector identifying the position or text range within the resource.
    public var text: TextSelector?

    /// CSS selector targeting the element or range within the resource.
    public var cssSelector: CSSSelector?

    public var isRefined: Bool {
        (progression ?? 0) > 0 || text != nil || cssSelector != nil
    }

    public init(
        href: AnyURL,
        progression: Progression? = nil,
        text: TextSelector? = nil,
        cssSelector: CSSSelector? = nil
    ) {
        self.href = href
        self.progression = progression
        self.text = text
        self.cssSelector = cssSelector
    }
}

/// A reference within an image resource.
///
/// An ``ImageReference`` can pinpoint a precise spatial clip within the image
/// resource using a ``SpatialSelector``.
public struct ImageReference: ResourceReference {
    /// URL of the image resource within the publication.
    public var href: AnyURL

    /// Selector identifying the spatial clip within the resource, if any.
    public var spatial: SpatialSelector?

    public var isRefined: Bool {
        spatial != nil
    }

    public init(
        href: AnyURL,
        spatial: SpatialSelector? = nil
    ) {
        self.href = href
        self.spatial = spatial
    }
}

/// A reference within an audio resource.
///
/// An ``AudioReference`` can pinpoint a precise time instant or clip within the
/// audio resource using a ``TemporalSelector``.
public struct AudioReference: ResourceReference {
    /// URL of the audio resource within the publication.
    public var href: AnyURL

    /// Selector identifying the time position or clip within the resource, if
    /// any.
    public var temporal: TemporalSelector?

    public var isRefined: Bool {
        temporal.map { !$0.isAtStart } ?? false
    }

    public init(
        href: AnyURL,
        temporal: TemporalSelector? = nil
    ) {
        self.href = href
        self.temporal = temporal
    }
}

/// A reference within a PDF resource.
public struct PDFReference: ResourceReference {
    /// URL of the PDF resource within the publication.
    public var href: AnyURL

    /// Progression within the PDF document, expressed as a percentage between 0
    /// and 1.
    public var progression: Progression?

    /// Selector identifying the position or text range within the resource.
    public var text: TextSelector?

    /// Identifies a page or an area in a page within the PDF document.
    public var page: PDFSelector?

    public var isRefined: Bool {
        (progression ?? 0) > 0 || text != nil || (page.map { !$0.isAtStart } ?? false)
    }

    public init(
        href: AnyURL,
        progression: Progression? = nil,
        text: TextSelector? = nil,
        page: PDFSelector? = nil
    ) {
        self.href = href
        self.progression = progression
        self.text = text
        self.page = page
    }
}

// MARK: - Value Types

/// 1-based index of a pre-computed position within the publication reading
/// order.
public typealias Position = Int

/// Progression through a resource or the whole publication, expressed as a
/// percentage between 0 and 1.
public typealias Progression = Double
