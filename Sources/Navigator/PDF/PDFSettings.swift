//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared
import ReadiumInternal

/// Holds a set of current settings for a `PDFNavigatorViewController`.
public struct PDFSettings: ConfigurableSettings {

    /// Spacing between pages, in points.
    public let pageSpacing: RangeSetting<Double>

    /// Direction of the reading progression inside and across PDF documents.
    public let readingProgression: EnumSetting<ReadingProgression>

    /// Indicates whether the user will scroll to navigate through the document, instead of using a
    /// synthetic pagination.
    public let scroll: Setting<Bool>

    /// Indicates the scrollg axis when scrolling is enabled.
    public let scrollAxis: EnumSetting<Axis>

    /// Indicates the condition to be met for the PDF document to be rendered within a synthetic
    /// spread.
    public let spread: EnumSetting<Spread>

    /// Indicates whether the scrollbar should be visible while scrolling.
    public let visibleScrollbar: Setting<Bool>
}

/// Provides default fallback values and ranges for PDF settings.
public struct PDFSettingsDefaults {

    /// Indicates the default spacing between pages, in points.
    public var pageSpacing: Double = 10

    /// Available range for the page spacing, in points.
    public var pageSpacingRange: ClosedRange<Double> = 0...50

    /// Strategy used to increment or decrement the page spacing.
    public var pageSpacingProgressionStrategy: AnyProgressionStrategy<Double> =
        IncrementProgressionStrategy(increment: 5).eraseToAnyProgressionStrategy()

    /// Indicates the default reading progression.
    public var readingProgression: ReadingProgression = .ltr

    /// Indicates whether scrolling is enabled by default.
    public var scroll: Bool = false

    /// Indicates the default axis when scrolling.
    public var scrollAxis: Axis = .vertical

    /// Indicates whether the publication is displayed in a synthetic spread by default.
    public var spread: Spread = .auto

    /// Indicates whether the scrollbar is visible by default.
    public var visibleScrollbar: Bool = true
}

class PDFSettingsFactory {

    private let defaults: PDFSettingsDefaults

    private let readingProgressions: [ReadingProgression] = [.ltr, .rtl]
    private let scrollAxes: [Axis] = [.vertical, .horizontal]
    private let spreads: [Spread] = [.auto, .never, .always]

    private let forceScrollActivator: SettingActivator

    init(defaults: PDFSettingsDefaults) {
        self.defaults = defaults

        self.forceScrollActivator = ForcePreferenceSettingActivator(
            key: .scroll,
            value: true,
            valueFromPreferences: { $0[.scroll] ?? defaults.scroll }
        )
    }

    func settings(metadata: Metadata, preferences: Preferences) -> PDFSettings {
        PDFSettings(
            pageSpacing: RangeSetting(
                key: .pageSpacing,
                value: preferences[.pageSpacing]?.clamped(to: defaults.pageSpacingRange)
                    ?? defaults.pageSpacing,
                range: defaults.pageSpacingRange,
                suggestedProgression: defaults.pageSpacingProgressionStrategy,
                formatValue: { String(format: "%.0f pt", $0) }
            ),
            readingProgression: EnumSetting(
                key: .readingProgression,
                value: readingProgressions.firstMemberFrom(
                        preferences[.readingProgression],
                        metadata.readingProgression
                    ) ?? defaults.readingProgression,
                values: readingProgressions
            ),
            scroll: Setting(
                key: .scroll,
                value: preferences[.scroll] ?? defaults.scroll
            ),
            scrollAxis: EnumSetting(
                key: .scrollAxis,
                value: preferences[.scrollAxis] ?? defaults.scrollAxis,
                values: scrollAxes,
                activator: forceScrollActivator
            ),
            spread: EnumSetting(
                key: .spread,
                value: preferences[.spread] ?? defaults.spread,
                values: spreads
            ),
            visibleScrollbar: Setting(
                key: .visibleScrollbar,
                value: preferences[.visibleScrollbar] ?? defaults.visibleScrollbar
            )
        )
    }
}

private extension SettingKey {
    static var pageSpacing: SettingKey<Double> { .init("pageSpacing") }
    static var readingProgression: SettingKey<ReadingProgression> { .init("readingProgression") }
    static var scrollAxis: SettingKey<Axis> { .init("scrollAxis") }
    static var scroll: SettingKey<Bool> { .init("scroll") }
    static var spread: SettingKey<Spread> { .init("spread") }
    static var visibleScrollbar: SettingKey<Bool> { .init("visibleScrollbar") }
}