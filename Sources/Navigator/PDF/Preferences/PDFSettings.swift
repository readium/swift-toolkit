//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumShared

/// Setting values of the `PDFNavigatorViewController`.
///
/// See `PDFPreferences`
public struct PDFSettings: ConfigurableSettings {
    public let backgroundColor: Color?
    public let offsetFirstPage: Bool
    public let pageSpacing: Double
    public let readingProgression: ReadingProgression
    public let scroll: Bool
    public let scrollAxis: Axis
    public let spread: Spread
    public let visibleScrollbar: Bool

    init(preferences: PDFPreferences, defaults: PDFDefaults, metadata: Metadata) {
        backgroundColor = preferences.backgroundColor
            ?? defaults.backgroundColor

        offsetFirstPage = preferences.offsetFirstPage
            ?? defaults.offsetFirstPage
            ?? false

        pageSpacing = preferences.pageSpacing
            ?? defaults.pageSpacing
            ?? 0

        readingProgression = preferences.readingProgression
            ?? ReadingProgression(metadata.readingProgression)
            ?? defaults.readingProgression
            ?? .ltr

        scroll = preferences.scroll
            ?? defaults.scroll
            ?? false

        scrollAxis = preferences.scrollAxis
            ?? defaults.scrollAxis
            ?? .vertical

        spread = preferences.spread
            ?? defaults.spread
            ?? .auto

        visibleScrollbar = preferences.visibleScrollbar
            ?? defaults.visibleScrollbar
            ?? true
    }
}

/// Default setting values for the PDF navigator.
///
/// These values will be used when no publication metadata or user preference
/// takes precedence.
///
/// See `PDFPreferences`.
public struct PDFDefaults {
    public var backgroundColor: Color?
    public var offsetFirstPage: Bool?
    public var pageSpacing: Double?
    public var readingProgression: ReadingProgression?
    public var scroll: Bool?
    public var scrollAxis: Axis?
    public var spread: Spread?
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
        self.backgroundColor = backgroundColor
        self.offsetFirstPage = offsetFirstPage
        self.pageSpacing = pageSpacing
        self.readingProgression = readingProgression
        self.scroll = scroll
        self.scrollAxis = scrollAxis
        self.spread = spread
        self.visibleScrollbar = visibleScrollbar
    }
}
