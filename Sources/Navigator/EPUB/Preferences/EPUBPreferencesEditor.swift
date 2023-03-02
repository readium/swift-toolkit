//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Editor for a set of `EPUBPreferences`.
///
/// Use `EPUBPreferencesEditor` to assist you in building a preferences user
/// interface or modifying existing preferences. It includes rules for
/// adjusting preferences, such as the supported values or ranges.
public final class EPUBPreferencesEditor: StatefulPreferencesEditor<EPUBPreferences, EPUBSettings> {

    private let epubLayout: EPUBLayout

    public init(
        initialPreferences: EPUBPreferences,
        metadata: Metadata,
        defaults: EPUBDefaults
    ) {
        self.epubLayout = metadata.presentation.layout ?? .reflowable

        super.init(
            initialPreferences: initialPreferences,
            settings: { EPUBSettings(preferences: $0, defaults: defaults, metadata: metadata) }
        )
    }

    /// Default background color.
    ///
    /// For fixed-layout publications, it applies to the navigator background
    /// but not the publication pages.
    ///
    /// When unset, the current `theme` background color is effective.
    public lazy var backgroundColor: AnyPreference<Color> =
        preference(
            preference: \.backgroundColor,
            effectiveValue: { [unowned self] in
                return $0.settings.backgroundColor
                    ?? (theme.value ?? theme.effectiveValue).backgroundColor
            },
            isEffective: { [unowned self] _ in preferences.backgroundColor != nil }
        )

    /// Number of reflowable columns to display (one-page view or two-page spread).
    ///
    /// Only effective when:
    ///  - the publication is reflowable
    ///  - `scroll` is off
    public lazy var columnCount: AnyEnumPreference<ColumnCount> =
        enumPreference(
            preference: \.columnCount,
            setting: \.columnCount,
            isEffective: { [unowned self] in
                return epubLayout == .reflowable
                    && !$0.settings.scroll
            },
            supportedValues: [.auto, .one, .two]
        )

    /// Default typeface for the text.
    ///
    /// Only effective with reflowable publications.
    public lazy var fontFamily: AnyPreference<FontFamily?> =
        preference(
            preference: \.fontFamily,
            setting: \.fontFamily,
            isEffective: { [unowned self] _ in epubLayout == .reflowable }
        )

    /// Base text font size as a percentage. Default to 100%.
    ///
    /// Note that allowing a font size that is too large could break the pagination.
    ///
    /// Only effective with reflowable publications.
    public lazy var fontSize: AnyRangePreference<Double> =
        rangePreference(
            preference: \.fontSize,
            setting: \.fontSize,
            isEffective: { [unowned self] _ in epubLayout == .reflowable },
            supportedRange: 0.1...5.0,
            progressionStrategy: .increment(0.1),
            format: \.percentageString
        )

    /// Default boldness for the text as a percentage.
    ///
    /// If you want to change the boldness of all text, including headers, you can use this with
    /// `textNormalization`.
    ///
    /// Only effective with reflowable publications.
    public lazy var fontWeight: AnyRangePreference<Double> =
        rangePreference(
            preference: \.fontWeight,
            effectiveValue: { $0.settings.fontWeight ?? 1.0 },
            isEffective: { [unowned self] in
                return epubLayout == .reflowable
                    && $0.preferences.fontWeight != nil
            },
            supportedRange: 0.0...2.5,
            progressionStrategy: .increment(0.25),
            format: \.percentageString
        )

    /// Enable hyphenation for latin languages.
    ///
    /// Only effective when:
    ///  - the publication is reflowable
    ///  - `publisherStyles` is off
    ///  - the layout is LTR
    public lazy var hyphens: AnyPreference<Bool> =
        preference(
            preference: \.hyphens,
            effectiveValue: { $0.settings.hyphens ?? false },
            isEffective: { [unowned self] in
                return epubLayout == .reflowable
                    && $0.settings.cssLayout.stylesheets == .default
                    && !$0.settings.publisherStyles
                    && $0.preferences.hyphens != nil
            }
        )

    /// Filter applied to images in dark theme.
    ///
    /// Only effective when:
    ///  - the publication is reflowable
    ///  - the `theme` is set to `Theme.DARK`
    public lazy var imageFilter: AnyEnumPreference<ImageFilter?> =
        enumPreference(
            preference: \.imageFilter,
            setting: \.imageFilter,
            isEffective: { $0.settings.theme == .dark },
            supportedValues: [.darken, .invert]
        )

    /// Language of the publication content.
    ///
    /// This has an impact on the resolved layout (e.g. LTR, RTL).
    public lazy var language: AnyPreference<Language?> =
        preference(
            preference: \.language,
            setting: \.language,
            isEffective: { _ in true }
        )

    /// Space between letters.
    ///
    /// Only effective when:
    ///  - the publication is reflowable
    ///  - `publisherStyles` is off
    ///  - the layout is LTR
    public lazy var letterSpacing: AnyRangePreference<Double> =
        rangePreference(
            preference: \.letterSpacing,
            effectiveValue: { $0.settings.letterSpacing ?? 0.0 },
            isEffective: { [unowned self] in
                return epubLayout == .reflowable
                    && $0.settings.cssLayout.stylesheets == .default
                    && !$0.settings.publisherStyles
                    && $0.preferences.letterSpacing != nil
            },
            supportedRange: 0.0...1.0,
            progressionStrategy: .increment(0.1),
            format: \.percentageString
        )

    /// Enable ligatures in Arabic.
    ///
    /// Only effective when:
    ///  - the publication is reflowable
    ///  - `publisherStyles` is off
    ///  - the layout is RTL
    public lazy var ligatures: AnyPreference<Bool> =
        preference(
            preference: \.ligatures,
            effectiveValue: { $0.settings.ligatures ?? false },
            isEffective: { [unowned self] in
                return epubLayout == .reflowable
                    && $0.settings.cssLayout.stylesheets == .rtl
                    && !$0.settings.publisherStyles
                    && $0.preferences.ligatures != nil
            }
        )

    /// Leading line height.
    ///
    /// Only effective when:
    ///  - the publication is reflowable
    ///  - `publisherStyles` is off
    public lazy var lineHeight: AnyRangePreference<Double> =
        rangePreference(
            preference: \.lineHeight,
            effectiveValue: { $0.settings.lineHeight ?? 1.2 },
            isEffective: { [unowned self] in
                return epubLayout == .reflowable
                    && !$0.settings.publisherStyles
                    && $0.preferences.lineHeight != nil
            },
            supportedRange: 1.0...2.0,
            progressionStrategy: .increment(0.1),
            format: { $0.formatDecimal(maximumFractionDigits: 5) }
        )

    /// Factor applied to horizontal margins. Default to 1.
    ///
    /// Only effective with reflowable publications.
    public lazy var pageMargins: AnyRangePreference<Double> =
        rangePreference(
            preference: \.pageMargins,
            setting: \.pageMargins,
            isEffective: { [unowned self] _ in epubLayout == .reflowable },
            supportedRange: 0.0...4.0,
            progressionStrategy: .increment(0.3),
            format: { $0.formatDecimal(maximumFractionDigits: 5) }
        )

    /// Text indentation for paragraphs.
    ///
    /// Only effective when:
    ///  - the publication is reflowable
    ///  - `publisherStyles` is off
    ///  - the layout is LTR or RTL
    public lazy var paragraphIndent: AnyRangePreference<Double> =
        rangePreference(
            preference: \.paragraphIndent,
            effectiveValue: { $0.settings.paragraphIndent ?? 0.0 },
            isEffective: { [unowned self] in
                return epubLayout == .reflowable
                    && [.default, .rtl].contains($0.settings.cssLayout.stylesheets)
                    && !$0.settings.publisherStyles
                    && $0.preferences.paragraphIndent != nil
            },
            supportedRange: 0.0...3.0,
            progressionStrategy: .increment(0.2),
            format: \.percentageString
        )

    /// Vertical margins for paragraphs.
    ///
    /// Only effective when:
    ///  - the publication is reflowable
    ///  - `publisherStyles` is off
    public lazy var paragraphSpacing: AnyRangePreference<Double> =
        rangePreference(
            preference: \.paragraphSpacing,
            effectiveValue: { $0.settings.paragraphSpacing ?? 0.0 },
            isEffective: { [unowned self] in
                return epubLayout == .reflowable
                    && !$0.settings.publisherStyles
                    && $0.preferences.paragraphSpacing != nil
            },
            supportedRange: 0.0...2.0,
            progressionStrategy: .increment(0.1),
            format: \.percentageString
        )

    /// Indicates whether the original publisher styles should be observed. Many advanced settings
    /// require this to be off.
    ///
    /// Only effective with reflowable publications.
    public lazy var publisherStyles: AnyPreference<Bool> =
        preference(
            preference: \.publisherStyles,
            setting: \.publisherStyles,
            isEffective: { [unowned self] _ in epubLayout == .reflowable }
        )

    /// Direction of the reading progression across resources.
    ///
    /// This can be changed to influence directly the layout (e.g. LTR or RTL).
    public lazy var readingProgression: AnyEnumPreference<ReadingProgression> =
        enumPreference(
            preference: \.readingProgression,
            setting: \.readingProgression,
            isEffective: { _ in true },
            supportedValues: [.ltr, .rtl]
        )

    /// Indicates if the overflow of resources should be handled using scrolling instead of synthetic
    /// pagination.
    ///
    /// Only effective with reflowable publications.
    public lazy var scroll: AnyPreference<Bool> =
        preference(
            preference: \.scroll,
            setting: \.scroll,
            isEffective: { [unowned self] _ in epubLayout == .reflowable }
        )

    /// Indicates if the fixed-layout publication should be rendered with a synthetic spread
    /// (dual-page).
    ///
    /// Only effective with fixed-layout publications.
    public lazy var spread: AnyEnumPreference<Spread> =
        enumPreference(
            preference: \.spread,
            setting: \.spread,
            isEffective: { [unowned self] _ in epubLayout == .fixed },
            supportedValues: [.never, .always]
        )

    /// Page text alignment.
    ///
    /// Only effective when:
    ///  - the publication is reflowable
    ///  - `publisherStyles` is off
    ///  - the layout is LTR or RTL
    public lazy var textAlign: AnyEnumPreference<TextAlignment?> =
        enumPreference(
            preference: \.textAlign,
            setting: \.textAlign,
            isEffective: { [unowned self] in
                return epubLayout == .reflowable
                    && [.default, .rtl].contains($0.settings.cssLayout.stylesheets)
                    && !$0.settings.publisherStyles
                    && $0.preferences.textAlign != nil
            },
            supportedValues: [.start, .left, .right, .justify]
        )

    /// Default page text color.
    ///
    /// When unset, the current `theme` text color is effective.
    /// Only effective with reflowable publications.
    public lazy var textColor: AnyPreference<Color> =
        preference(
            preference: \.textColor,
            effectiveValue: { [unowned self] in
                return $0.settings.textColor
                    ?? (theme.value ?? theme.effectiveValue).contentColor
            },
            isEffective: { [unowned self] in
                return epubLayout == .reflowable
                    && $0.preferences.textColor != nil
            }
        )

    /// Normalize text styles to increase accessibility.
    ///
    /// Only effective with reflowable publications.
    public lazy var textNormalization: AnyPreference<Bool> =
        preference(
            preference: \.textNormalization,
            setting: \.textNormalization,
            isEffective: { [unowned self] _ in epubLayout == .reflowable }
        )

    /// Reader theme (light, dark, sepia).
    ///
    /// Only effective with reflowable publications.
    public lazy var theme: AnyEnumPreference<Theme> =
        enumPreference(
            preference: \.theme,
            setting: \.theme,
            isEffective: { [unowned self] _ in epubLayout == .reflowable },
            supportedValues: [.light, .dark, .sepia]
        )

    /// Scale applied to all element font sizes.
    ///
    /// Only effective when:
    ///  - the publication is reflowable
    ///  - `publisherStyles` is off
    public lazy var typeScale: AnyRangePreference<Double> =
        rangePreference(
            preference: \.typeScale,
            effectiveValue: { [unowned self] in $0.settings.typeScale ?? 1.2 },
            isEffective: { [unowned self] in
                return epubLayout == .reflowable
                    && !$0.settings.publisherStyles
                    && preferences.typeScale != nil
            },
            supportedRange: 1.0...2.0,
            progressionStrategy: .steps(1.0, 1.067, 1.125, 1.2, 1.25, 1.333, 1.414, 1.5, 1.618),
            format: { $0.formatDecimal(maximumFractionDigits: 5) }
        )

    /// Indicates whether the text should be laid out vertically. This is used for example with CJK
    /// languages. This setting is automatically derived from the language if no preference is given.
    ///
    /// Only effective with reflowable publications.
    public lazy var verticalText: AnyPreference<Bool> =
        preference(
            preference: \.verticalText,
            setting: \.verticalText,
            isEffective: { [unowned self] _ in epubLayout == .reflowable }
        )

    /// Space between words.
    ///
    /// Only effective when:
    ///  - the publication is reflowable
    ///  - the layout is LTR
    public lazy var wordSpacing: AnyRangePreference<Double> =
        rangePreference(
            preference: \.wordSpacing,
            effectiveValue: { [unowned self] in $0.settings.wordSpacing ?? 0.0 },
            isEffective: { [unowned self] in
                return epubLayout == .reflowable
                    && $0.settings.cssLayout.stylesheets == .default
                    && !$0.settings.publisherStyles
                    && $0.preferences.wordSpacing != nil
            },
            supportedRange: 0.0...1.0,
            progressionStrategy: .increment(0.1),
            format: \.percentageString
        )

}