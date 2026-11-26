//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Setting values of the `PDFNavigatorViewController`.
///
/// The navigator resolves them from the submitted `PDFPreferences`. Use
/// `init(publication:preferences:defaults:)` to resolve them yourself, for
/// example to check which settings are effective with `isEffective(_:)`.
///
/// See `PDFPreferences`
public struct PDFSettings: ConfigurableSettings, Sendable {
    public let backgroundColor: Color?
    public let fit: Fit
    public let offsetFirstPage: Bool
    public let pageSpacing: Double
    public let readingProgression: ReadingProgression
    public let scroll: Bool
    public let scrollAxis: Axis
    public let spread: Spread
    public let visibleScrollbar: Bool

    /// Resolves the settings applied by the PDF navigator to `publication`
    /// with the given `preferences`.
    ///
    /// A preference takes precedence over the publication metadata, which
    /// takes precedence over the `defaults`.
    public init(
        publication: Publication,
        preferences: PDFPreferences,
        defaults: PDFDefaults = PDFDefaults()
    ) {
        let metadata = publication.metadata

        backgroundColor = preferences.backgroundColor
            ?? defaults.backgroundColor

        fit = preferences.fit
            ?? defaults.fit
            ?? .auto

        offsetFirstPage = preferences.offsetFirstPage
            ?? defaults.offsetFirstPage
            ?? false

        pageSpacing = max(
            preferences.pageSpacing
                ?? defaults.pageSpacing
                ?? 0,
            0
        )

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

public extension PDFSettings {
    /// Indicates whether the given `setting` would take effect if it was set
    /// by a preference, with the other settings.
    ///
    /// Use it to disable the controls of the settings which have no effect.
    ///
    /// The rules of each setting are:
    /// - Always effective: `backgroundColor`, `pageSpacing`, `scroll`.
    /// - `fit`, `scrollAxis`, `visibleScrollbar`: when `scroll` is on.
    /// - `readingProgression`: when `scroll` is off, because of a PDFKit
    ///   limitation.
    /// - `spread`: when `scroll` is off, or with a vertical `scrollAxis`.
    /// - `offsetFirstPage`: like `spread`, and when `spread` is not `.never`.
    ///
    /// - Parameter setting: Key path of a setting, e.g. `\.scrollAxis`.
    ///   Other key paths are a programming error.
    func isEffective(_ setting: PartialKeyPath<PDFSettings>) -> Bool {
        let hasSpread = !scroll || scrollAxis == .vertical

        switch setting {
        case \.backgroundColor, \.pageSpacing, \.scroll:
            return true
        case \.fit, \.scrollAxis, \.visibleScrollbar:
            return scroll
        case \.readingProgression:
            // A bug in PDFKit prevents the PDF from being laid out as RTL
            // if the scroll mode is enabled.
            // https://stackoverflow.com/questions/64399748/pdfkit-pdfview-wont-be-rtl-without-usepageviewcontroller
            return !scroll
        case \.spread:
            return hasSpread
        case \.offsetFirstPage:
            return hasSpread && spread != .never
        default:
            preconditionFailure("\(setting) is not a setting of PDFSettings")
        }
    }
}

/// Default setting values for the PDF navigator.
///
/// These values will be used when no publication metadata or user preference
/// takes precedence.
///
/// See `PDFPreferences`.
public struct PDFDefaults: Sendable {
    public var backgroundColor: Color?
    public var fit: Fit?
    public var offsetFirstPage: Bool?
    public var pageSpacing: Double?
    public var readingProgression: ReadingProgression?
    public var scroll: Bool?
    public var scrollAxis: Axis?
    public var spread: Spread?
    public var visibleScrollbar: Bool?

    public init(
        backgroundColor: Color? = nil,
        fit: Fit? = nil,
        offsetFirstPage: Bool? = nil,
        pageSpacing: Double? = nil,
        readingProgression: ReadingProgression? = nil,
        scroll: Bool? = nil,
        scrollAxis: Axis? = nil,
        spread: Spread? = nil,
        visibleScrollbar: Bool? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.fit = fit
        self.offsetFirstPage = offsetFirstPage
        self.pageSpacing = pageSpacing.map { max($0, 0) }
        self.readingProgression = readingProgression
        self.scroll = scroll
        self.scrollAxis = scrollAxis
        self.spread = spread
        self.visibleScrollbar = visibleScrollbar
    }
}
