//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Editor for a set of `PDFPreferences`.
///
/// Use `PDFPreferencesEditor` to assist you in building a preferences user
/// interface or modifying existing preferences. It includes rules for
/// adjusting preferences, such as the supported values or ranges.
public final class PDFPreferencesEditor: StatefulPreferencesEditor<PDFPreferences, PDFSettings> {

    public init(initialPreferences: PDFPreferences, metadata: Metadata, defaults: PDFDefaults) {
        super.init(
            initialPreferences: initialPreferences,
            emptyPreferences: PDFPreferences(),
            makeSettings: {
                PDFSettings(preferences: $0, defaults: defaults, metadata: metadata)
            }
        )
    }

    /// Spacing between pages in points.
    public lazy var pageSpacing: AnyRangePreference<Double> =
        rangePreference(
            preference: \.pageSpacing,
            setting: \.pageSpacing,
            isEffective: { settings in
                !settings.scroll && settings.spread != .never
            },
            format: { $0.format(maximumFractionDigits: 1) + " pt" },
            supportedRange: 0...50,
            progressionStrategy: .increment(5.0)
        )

    /// Direction of the horizontal progression across pages.
    public lazy var readingProgression: AnyEnumPreference<ReadingProgression> =
        enumPreference(
            preference: \.readingProgression,
            setting: \.readingProgression,
            isEffective: { _ in true },
            supportedValues: [.ltr, .rtl]
        )

    /// Indicates if pages should be handled using scrolling instead of
    /// pagination.
    public lazy var scroll: AnyPreference<Bool> =
        preference(
            preference: \.scroll,
            setting: \.scroll,
            isEffective: { _ in true }
        )

    /// Indicates the axis along which pages should be laid out in scroll mode.
    ///
    /// Only effective when `scroll` is on.
    public lazy var scrollAxis: AnyEnumPreference<Axis> =
        enumPreference(
            preference: \.scrollAxis,
            setting: \.scrollAxis,
            isEffective: { settings in settings.scroll },
            supportedValues: [.vertical, .horizontal]
        )

    /// Indicates if the publication should be rendered with a synthetic spread
    /// (dual-page).
    ///
    /// Only effective when `scroll` is off.
    public lazy var spread: AnyEnumPreference<Spread> =
        enumPreference(
            preference: \.spread,
            setting: \.spread,
            isEffective: { settings in !settings.scroll },
            supportedValues: [.auto, .never, .always]
        )

    /// Indicates whether the scrollbar should be visible while scrolling.
    ///
    /// Only effective when `scroll` is on.
    public lazy var visibleScrollbar: AnyPreference<Bool> =
        preference(
            preference: \.visibleScrollbar,
            setting: \.visibleScrollbar,
            isEffective: { settings in settings.scroll }
        )
}
