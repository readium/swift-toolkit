//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Preferences for the `PDFNavigatorViewController`.
public struct PDFPreferences: ConfigurablePreferences {

    public static let empty: PDFPreferences = PDFPreferences()
    
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
        offsetFirstPage: Bool? = nil,
        pageSpacing: Double? = nil,
        readingProgression: ReadingProgression? = nil,
        scroll: Bool? = nil,
        scrollAxis: Axis? = nil,
        spread: Spread? = nil,
        visibleScrollbar: Bool? = nil
    ) {
        precondition(pageSpacing == nil || pageSpacing! >= 0)
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
    public static func filterSharedPreferences(_ preferences: PDFPreferences) -> PDFPreferences {
        var prefs = preferences
        prefs.offsetFirstPage = nil
        prefs.readingProgression = nil
        prefs.spread = nil
        return prefs
    }

    /// Returns a new `PDFPreferences` keeping only the publication-specific
    /// preferences.
    public static func filterPublicationPreferences(_ preferences: PDFPreferences) -> PDFPreferences {
        PDFPreferences(
            offsetFirstPage: preferences.offsetFirstPage,
            readingProgression: preferences.readingProgression,
            spread: preferences.spread
        )
    }
}