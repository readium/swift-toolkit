//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Editor for a set of `PDFPreferences`.
///
/// Use `PDFPreferencesEditor` to assist you in building a preferences user
/// interface or modifying existing preferences. It includes rules for
/// adjusting preferences, such as the supported values or ranges.
public final class PDFPreferencesEditor: StatefulPreferencesEditor<PDFPreferences, PDFSettings> {
    private let defaults: PDFDefaults

    public init(initialPreferences: PDFPreferences, metadata: Metadata, defaults: PDFDefaults) {
        self.defaults = defaults

        super.init(
            initialPreferences: initialPreferences,
            settings: { PDFSettings(preferences: $0, defaults: defaults, metadata: metadata) }
        )
    }

    /// Background color behind the document pages.
    public lazy var backgroundColor: AnyPreference<Color?> =
        preference(
            preference: \.backgroundColor,
            setting: \.backgroundColor,
            isEffective: { $0.preferences.backgroundColor != nil }
        )

    /// Indicates if the first page should be displayed in its own spread.
    ///
    /// Only effective when `spread` is not off.
    public lazy var offsetFirstPage: AnyPreference<Bool> =
        preference(
            preference: \.offsetFirstPage,
            setting: \.offsetFirstPage,
            defaultEffectiveValue: defaults.offsetFirstPage ?? false,
            isEffective: {
                (!$0.settings.scroll || $0.settings.scrollAxis == .vertical)
                    && $0.settings.spread != .never
            }
        )

    /// Spacing between pages in points.
    public lazy var pageSpacing: AnyRangePreference<Double> =
        rangePreference(
            preference: \.pageSpacing,
            setting: \.pageSpacing,
            defaultEffectiveValue: defaults.pageSpacing ?? 0,
            isEffective: { _ in true },
            supportedRange: 0 ... 200,
            progressionStrategy: .increment(4.0),
            format: { String(format: "%.1f pt", $0) }
        )

    /// Direction of the horizontal progression across pages.
    public lazy var readingProgression: AnyEnumPreference<ReadingProgression> =
        enumPreference(
            preference: \.readingProgression,
            setting: \.readingProgression,
            defaultEffectiveValue: defaults.readingProgression ?? .ltr,
            isEffective: {
                // A bug in PDFKit prevents the PDF from being laid out as RTL
                // if the scroll mode is enabled.
                // https://stackoverflow.com/questions/64399748/pdfkit-pdfview-wont-be-rtl-without-usepageviewcontroller
                !$0.settings.scroll
            },
            supportedValues: [.ltr, .rtl]
        )

    /// Indicates if pages should be handled using scrolling instead of
    /// pagination.
    public lazy var scroll: AnyPreference<Bool> =
        preference(
            preference: \.scroll,
            setting: \.scroll,
            defaultEffectiveValue: defaults.scroll ?? false,
            isEffective: { _ in true }
        )

    /// Indicates the axis along which pages should be laid out in scroll mode.
    ///
    /// Only effective when `scroll` is on.
    public lazy var scrollAxis: AnyEnumPreference<Axis> =
        enumPreference(
            preference: \.scrollAxis,
            setting: \.scrollAxis,
            defaultEffectiveValue: defaults.scrollAxis ?? .horizontal,
            isEffective: { $0.settings.scroll },
            supportedValues: [.vertical, .horizontal]
        )

    /// Indicates if the publication should be rendered with a synthetic spread
    /// (dual-page).
    public lazy var spread: AnyEnumPreference<Spread> =
        enumPreference(
            preference: \.spread,
            setting: \.spread,
            defaultEffectiveValue: defaults.spread ?? .auto,
            isEffective: {
                !$0.settings.scroll || $0.settings.scrollAxis == .vertical
            },
            supportedValues: [.auto, .never, .always]
        )

    /// Indicates whether the scrollbar should be visible while scrolling.
    ///
    /// Only effective when `scroll` is on.
    public lazy var visibleScrollbar: AnyPreference<Bool> =
        preference(
            preference: \.visibleScrollbar,
            setting: \.visibleScrollbar,
            defaultEffectiveValue: defaults.visibleScrollbar ?? true,
            isEffective: { $0.settings.scroll }
        )
}
