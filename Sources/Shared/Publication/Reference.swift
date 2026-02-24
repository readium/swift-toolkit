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
}

// MARK: - Text Reference

/// A reference within a text-based resource (e.g. HTML).
///
/// A ``TextReference`` can pinpoint a precise position or text range inside the
/// resource using a ``TextSelector``.
public protocol TextReference: ResourceReference {
    /// Selector identifying the position or text range or position within the
    /// resource, if any.
    var text: TextSelector? { get }
}

/// Identifies a position or a range of text within a resource.
public enum TextSelector: Hashable, Sendable {
    /// Pinpoints a reference using surrounding text context, without selecting a
    /// range.
    case position(TextPosition)

    /// Selects an exact text range by quoting the target text and its
    /// surroundings.
    case quote(TextQuote)
}

/// Identifies a text range by quoting the exact text and its surrounding
/// context.
///
/// Inspired by the W3C Text Quote Selector and the WICG Scroll-to-Text Fragment
/// specifications.
///
/// - https://wicg.github.io/scroll-to-text-fragment/
/// - https://www.w3.org/TR/annotation-model/#text-quote-selector
public struct TextQuote: Hashable, Sendable {
    /// Text immediately preceding the selected range, used to disambiguate
    /// matches.
    public var before: String

    /// First text of the selected range.
    public var start: String

    /// Last text of the selected range. Empty when the quote is entirely
    /// contained within `start`.
    public var end: String

    /// Text immediately following the selected range, used to disambiguate
    /// matches.
    public var after: String

    public init(
        before: String = "",
        start: String,
        end: String = "",
        after: String = ""
    ) {
        self.before = before
        self.start = start
        self.end = end
        self.after = after
    }
}

/// Identifies a position within a text resource using surrounding text context,
/// without selecting a range.
///
/// Inspired by the W3C Text Position Selector and the WICG Scroll-to-Text
/// Fragment specifications.
///
/// - https://wicg.github.io/scroll-to-text-fragment/
/// - https://www.w3.org/TR/annotation-model/#text-position-selector
public struct TextPosition: Hashable, Sendable {
    /// Text immediately before the position.
    public var before: String

    /// Text immediately after the position.
    public var after: String

    public init(
        before: String = "",
        after: String = ""
    ) {
        self.before = before
        self.after = after
    }
}

// MARK: - Media Reference

/// A reference within a media resource.
///
/// A ``MediaReference`` can pinpoint a precise time instant or clip within the
/// media resource using a ``TemporalSelector``.
public struct MediaReference: ResourceReference {
    /// URL of the audio resource within the publication.
    public var href: AnyURL

    /// Selector identifying the time position or clip within the resource, if
    /// any.
    public var temporal: TemporalSelector?

    public init(
        href: AnyURL,
        temporal: TemporalSelector? = nil
    ) {
        self.href = href
        self.temporal = temporal
    }
}

// Unit for a spatial
// - https://www.w3.org/TR/media-frags/#naming-space

/// Identifies a time instant or clip within a media resource.
///
/// Follows the W3C Media Fragments URI specification for the temporal
/// dimension.
///
/// - https://www.w3.org/TR/media-frags/#naming-time
public enum TemporalSelector: Hashable, Sendable {
    /// A single point in time within the media stream.
    case position(TemporalPosition)

    /// A time range (clip) within the media stream.
    case clip(TemporalClip)
}

/// A single point in time within a media rendition.
public struct TemporalPosition: Hashable, Sendable {
    /// Time offset from the start of the media rendition, in seconds.
    public var time: TimeInterval

    public init(time: TimeInterval) {
        self.time = time
    }
}

/// A time range within a media rendition.
public struct TemporalClip: Hashable, Sendable {
    /// Start of the clip, in seconds from the beginning of the media rendition.
    public var start: TimeInterval?

    /// End of the clip, in seconds from the beginning of the media rendition.
    public var end: TimeInterval?

    public init(
        start: TimeInterval? = nil,
        end: TimeInterval? = nil
    ) {
        self.start = start
        self.end = end
    }
}

// MARK: - Image Reference

/// A reference within an image resource.
///
/// An ``ImageReference`` can pinpoint a precise spatial clip within the image
/// resource using a ``SpatialSelector``.
public struct ImageReference: ResourceReference {
    /// URL of the image resource within the publication.
    public var href: AnyURL

    /// Selector identifying the spatial clip within the resource, if any.
    public var spatial: SpatialSelector?

    public init(
        href: AnyURL,
        spatial: SpatialSelector? = nil
    ) {
        self.href = href
        self.spatial = spatial
    }
}

/// Identifies an area of pixels within a visual media resource.
///
/// Follows the W3C Media Fragments URI specification for the spatial
/// dimension.
///
/// - https://www.w3.org/TR/media-frags/#naming-space
public struct SpatialSelector: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public var unit: Unit

    public enum Unit: Hashable, Sendable {
        case percent
        case pixel
    }

    public init(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        unit: Unit
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.unit = unit
    }
}

// MARK: - Web Reference

/// A reference within a reflowable HTML or XHTML resource, as used by the EPUB
/// and web-based navigators.
public struct ReflowableWebReference: TextReference {
    /// URL of the HTML/XHTML resource within the publication.
    public var href: AnyURL

    /// Progression within the resource, expressed as a percentage between 0 and
    /// 1.
    public var progression: Progression?

    /// Pre-computed position index within the publication (>= 1).
    public var position: Position?

    /// Selector identifying the position or text range within the resource.
    public var text: TextSelector?

    /// CSS selector targeting the element or range within the resource.
    public var cssSelector: CSSSelector?

    public init(
        href: AnyURL,
        progression: Progression? = nil,
        position: Position? = nil,
        text: TextSelector? = nil,
        cssSelector: CSSSelector? = nil
    ) {
        self.href = href
        self.progression = progression
        self.position = position
        self.text = text
        self.cssSelector = cssSelector
    }
}

/// A reference within a fixed layout HTML or XHTML resource, as used by the FXL
/// EPUB navigator.
public struct FixedWebReference: TextReference {
    /// URL of the HTML/XHTML resource within the publication.
    public var href: AnyURL

    /// 1-based page number within the fixed layout publication.
    public var page: PageNumber?

    /// Selector identifying the position or text range within the resource.
    public var text: TextSelector?

    public init(
        href: AnyURL,
        page: PageNumber? = nil,
        text: TextSelector? = nil
    ) {
        self.href = href
        self.page = page
        self.text = text
    }
}

// MARK: - PDF Reference

/// A reference within a PDF resource.
public struct PDFReference: TextReference {
    /// URL of the PDF resource within the publication.
    public var href: AnyURL

    /// Progression within the PDF document, expressed as a percentage between 0
    /// and 1.
    public var progression: Progression?

    /// Selector identifying the position or text range within the resource.
    public var text: TextSelector?

    /// 1-based page number within the PDF resource.
    public var page: PageNumber?

    public init(
        href: AnyURL,
        progression: Progression? = nil,
        text: TextSelector? = nil,
        page: PageNumber? = nil
    ) {
        self.href = href
        self.progression = progression
        self.text = text
        self.page = page
    }
}

// MARK: - Value Types

/// 1-based page number within a page-based resource (e.g. PDF).
public typealias PageNumber = Int

/// 1-based index of a pre-computed position within the publication reading
/// order.
public typealias Position = Int

/// Progression through a resource or the whole publication, expressed as a
/// percentage between 0 and 1.
public typealias Progression = Double

/// A CSS selector string targeting an element or range within an HTML/XHTML
/// resource.
public typealias CSSSelector = String
