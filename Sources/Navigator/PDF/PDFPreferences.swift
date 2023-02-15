//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Preferences for the `PDFNavigatorViewController`.
public struct PDFPreferences: ConfigurablePreferences {

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
        pageSpacing: Double? = nil,
        readingProgression: ReadingProgression? = nil,
        scroll: Bool? = nil,
        scrollAxis: Axis? = nil,
        spread: Spread? = nil,
        visibleScrollbar: Bool? = nil
    ) {
        precondition(pageSpacing == nil || pageSpacing! >= 0)
        self.pageSpacing = pageSpacing
        self.readingProgression = readingProgression
        self.scroll = scroll
        self.scrollAxis = scrollAxis
        self.spread = spread
        self.visibleScrollbar = visibleScrollbar
    }
}
