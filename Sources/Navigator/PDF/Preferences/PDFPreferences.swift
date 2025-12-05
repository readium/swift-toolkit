//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Preferences for the `PDFNavigatorViewController`.
public struct PDFPreferences: ConfigurablePreferences {
    public static let empty: PDFPreferences = .init()

    /// Background color behind the document pages.
    public var backgroundColor: Color?

    /// Indicates if the first page should be displayed in its own spread.
    public var offsetFirstPage: Bool?

    /// Spacing between pages in points.
    public var pageSpacing: Double? {
        willSet { precondition(newValue == nil || newValue! >= 0) }
    }

    /// Direction of the horizontal progression across pages.
    public var readingProgression: ReadingProgression?

    /// Indicates if pages should be handled using scrolling instead of
    /// pagination.
    public var scroll: Bool?

    /// Indicates the axis along which pages should be laid out in scroll mode.
    public var scrollAxis: Axis?

    /// Indicates if the publication should be rendered with a synthetic spread
    /// (dual-page).
    public var spread: Spread?

    /// Indicates whether the scrollbar should be visible while scrolling.
    public var visibleScrollbar: Bool?

    public init(
        backgroundColor: Color? = nil,
        offsetFirstPage: Bool? = nil,
        pageSpacing: Double? = nil,
        readingProgression: ReadingProgression? = nil,
        scroll: Bool? = nil,
        scrollAxis: Axis? = nil,
        spread: Spread? = nil,
        visibleScrollbar: Bool? = nil
    ) {
        precondition(pageSpacing == nil || pageSpacing! >= 0)
        self.backgroundColor = backgroundColor
        self.offsetFirstPage = offsetFirstPage
        self.pageSpacing = pageSpacing
        self.readingProgression = readingProgression
        self.scroll = scroll
        self.scrollAxis = scrollAxis
        self.spread = spread
        self.visibleScrollbar = visibleScrollbar
    }

    public func merging(_ other: PDFPreferences) -> PDFPreferences {
        PDFPreferences(
            backgroundColor: other.backgroundColor ?? backgroundColor,
            offsetFirstPage: other.offsetFirstPage ?? offsetFirstPage,
            pageSpacing: other.pageSpacing ?? pageSpacing,
            readingProgression: other.readingProgression ?? readingProgression,
            scroll: other.scroll ?? scroll,
            scrollAxis: other.scrollAxis ?? scrollAxis,
            spread: other.spread ?? spread,
            visibleScrollbar: other.visibleScrollbar ?? visibleScrollbar
        )
    }

    /// Returns a new `PDFPreferences` with the publication-specific preferences
    /// removed.
    public func filterSharedPreferences() -> PDFPreferences {
        var prefs = self
        prefs.offsetFirstPage = nil
        prefs.readingProgression = nil
        return prefs
    }

    /// Returns a new `PDFPreferences` keeping only the publication-specific
    /// preferences.
    public func filterPublicationPreferences() -> PDFPreferences {
        PDFPreferences(
            offsetFirstPage: offsetFirstPage,
            readingProgression: readingProgression
        )
    }
}
