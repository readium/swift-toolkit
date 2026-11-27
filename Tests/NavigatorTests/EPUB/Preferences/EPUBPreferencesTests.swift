//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumNavigator
import ReadiumShared
import Testing
import UIKit

enum EPUBPreferencesTests {
    /// Keeps the settings tests exhaustive.
    ///
    /// A stored property missing from the settings resolution would still
    /// pass these tests if the fixtures left it `nil`, or gave it the value it
    /// is compared with. These tests list the stored properties with a
    /// `Mirror`, so they fail as soon as a new property is added to
    /// `EPUBPreferences` or `EPUBDefaults` without being set in the fixtures.
    @Suite("fixtures") struct Fixtures {
        @Test("the fixtures set every property")
        func complete() {
            #expect(unsetProperties(of: otherPreferences) == [])
            #expect(unsetProperties(of: allDefaults) == [])
        }

        @Test("the fixtures compared by the tests have a different value for every property")
        func distinct() {
            #expect(sameProperties(otherPreferences, allDefaults) == [])
            #expect(sameProperties(allDefaults, settings()) == [])
        }

        /// Names of the stored properties of `lhs` which have the same value
        /// in `rhs`.
        private func sameProperties(_ lhs: Any, _ rhs: Any) -> Set<String> {
            let rhsChildren = Mirror(reflecting: rhs).children
            return Set(
                Mirror(reflecting: lhs).children
                    .filter { child in
                        rhsChildren.contains {
                            $0.label == child.label
                                && unwrappedDescription($0.value) == unwrappedDescription(child.value)
                        }
                    }
                    .map { $0.label ?? "?" }
            )
        }
    }

    @Suite("settings") struct Settings {
        @Test("the settings when every preference is unset, with the default EPUBDefaults")
        func unset() {
            #expect(settings() == EPUBSettings(
                backgroundColor: nil,
                blendImages: false,
                columnCount: nil,
                darkenImages: nil,
                fit: .auto,
                fontFamily: nil,
                fontSize: 1.0,
                fontWeight: nil,
                fontWidth: nil,
                hyphens: nil,
                invertGaiji: false,
                invertImages: false,
                language: nil,
                letterSpacing: nil,
                ligatures: nil,
                lineHeight: nil,
                linkColor: nil,
                maximalLineLength: 1.0,
                minimalLineLength: nil,
                noRuby: false,
                offsetFirstPage: nil,
                optimalLineLength: 1.0,
                pageMargins: 1.0,
                paragraphIndent: nil,
                paragraphSpacing: nil,
                readingProgression: .ltr,
                scroll: false,
                spread: .auto,
                textAlign: nil,
                textColor: nil,
                textNormalization: false,
                verticalText: false,
                visitedColor: nil,
                wordSpacing: nil
            ))
        }

        @Test("the settings fall back on every default")
        func fallBackOnDefaults() {
            let resolved = Mirror(reflecting: settings(defaults: allDefaults)).children
            for (label, value) in Mirror(reflecting: allDefaults).children {
                let setting = resolved.first { $0.label == label }?.value
                #expect(setting.map(unwrappedDescription) == unwrappedDescription(value), "\(label ?? "?")")
            }
        }

        @Test("the preferences take precedence over every default")
        func preferencesTakePrecedence() {
            #expect(
                settings(preferences: otherPreferences, defaults: allDefaults)
                    == settings(preferences: otherPreferences)
            )
        }
    }

    @Suite("Readium CSS") struct CSS {
        @Test("emits only the default properties when every preference is unset")
        func unset() {
            let props = cssProperties()
                .compactMapValues { $0 }
            #expect(props == [
                "--RS__disableOverflow": "readium-noOverflow-on",
                "--USER__fontSize": "100.00000%",
                "--USER__view": "readium-paged-on",
            ])
        }

        @Test("emits each preference", arguments: cssTable)
        func emitted(preferences: EPUBPreferences, expected: [String: String?]) {
            let unset = cssProperties()
            let set = cssProperties(preferences: preferences)
            // A property removed by the preference is reported as `nil`.
            let changed = Dictionary(uniqueKeysWithValues: Set(unset.keys).union(set.keys)
                .filter { unset[$0] != set[$0] }
                .map { key -> (String, String?) in (key, set[key] ?? nil) })
            #expect(changed == expected)
        }

        @Test("the table sets every preference")
        func tableIsComplete() {
            let unset = cssTable
                .map { unsetProperties(of: $0.preferences) }
                .reduce(unsetProperties(of: EPUBPreferences())) { $0.intersection($1) }
            #expect(unset == [])
        }
    }

    /// Which settings apply, depending on the layouts of the reading
    /// order resources.
    @Suite("applicable settings") struct ApplicableSettings {
        private let fixedLayoutSettings: Set<String> = ["fit", "offsetFirstPage", "spread"]
        private let layoutIndependentSettings: Set<String> = ["backgroundColor", "language", "readingProgression"]

        @Test("are tested for every setting")
        func listsEverySetting() {
            let storedSettings = Set(Mirror(reflecting: settings()).children.compactMap(\.label))
                .subtracting(["layouts"])
            #expect(Set(allSettings.map(\.name)) == storedSettings)
            #expect(storedSettings == allPreferenceNames)
        }

        @Test("every setting applies in a reflowable publication, except the fixed-layout ones and the ones depending on the language or the columns")
        func reflowablePublication() {
            #expect(
                applicableSettings(settings()) == allPreferenceNames
                    .subtracting(fixedLayoutSettings)
                    // Applicable only with a CJK language, and with several columns.
                    .subtracting(["noRuby", "minimalLineLength"])
            )
        }

        @Test("the optional settings apply whether they are set or not")
        func optionalSettingsSetOrNot() {
            let unset = settings()
            #expect(unsetProperties(of: unset).isSuperset(of: allPreferenceNames.subtracting(unsetProperties(of: optionalPreferences))))
            #expect(applicableSettings(unset) == applicableSettings(settings(preferences: optionalPreferences)))
        }

        @Test("the settings of both layouts apply in a fixed-layout publication containing a reflowable resource", arguments: ["en", "ja"])
        func fixedLayoutPublicationWithReflowableResource(language: String) {
            let preferences = EPUBPreferences(language: Language(language))

            var reflowable = Link(href: "c2.xhtml", mediaType: .xhtml)
            reflowable.properties.epubLayout = .reflowable

            let mixed = settings(
                preferences: preferences,
                layout: .fixed,
                readingOrder: [Link(href: "c1.xhtml", mediaType: .xhtml), reflowable]
            )
            #expect(
                applicableSettings(mixed)
                    == applicableSettings(settings(preferences: preferences)).union(fixedLayoutSettings)
            )
        }

        @Test("only the fixed-layout settings apply in a fixed-layout publication")
        func fixedLayoutPublication() {
            #expect(applicableSettings(settings(layout: .fixed)) == fixedLayoutSettings.union(layoutIndependentSettings))
        }

        @Test("only the fixed-layout settings apply in a reflowable publication containing only fixed-layout resources")
        func reflowablePublicationWithoutReflowableResource() {
            #expect(applicableSettings(settings(readingOrder: fixedLayoutReadingOrder)) == fixedLayoutSettings.union(layoutIndependentSettings))
        }

        /// A reading order of fixed-layout resources, in a reflowable
        /// publication.
        private var fixedLayoutReadingOrder: [Link] {
            var fixed = Link(href: "c1.xhtml", mediaType: .xhtml)
            fixed.properties.epubLayout = .fixed
            return [
                fixed,
                Link(href: "p2.jpg", mediaType: .jpeg),
                Link(href: "p3.svg", mediaType: .svg),
            ]
        }
    }

    @Suite("fixed-layout settings") struct FixedLayout {
        @Test("offsetFirstPage doesn't apply when the spread is disabled by a preference or a default")
        func offsetFirstPageWithoutSpread() {
            let withoutSpread = settings(preferences: EPUBPreferences(spread: .never), layout: .fixed)
            #expect(withoutSpread.isApplicable(\.spread))
            #expect(!withoutSpread.isApplicable(\.offsetFirstPage))

            #expect(!settings(defaults: EPUBDefaults(spread: .never), layout: .fixed).isApplicable(\.offsetFirstPage))
            #expect(settings(layout: .fixed).isApplicable(\.offsetFirstPage))
        }
    }

    @Suite("language-specific settings") struct LanguageSpecific {
        private let languageSpecificSettings: Set<String> = [
            "hyphens", "letterSpacing", "ligatures", "noRuby", "paragraphIndent", "textAlign", "textNormalization", "wordSpacing",
        ]

        struct Applicable: Sendable, CustomTestStringConvertible {
            let name: String
            let language: String
            var verticalText: Bool = false
            let stylesheets: CSSLayout.Stylesheets
            let expected: Set<String>

            var testDescription: String {
                name
            }
        }

        @Test("the settings apply with the stylesheets supporting them", arguments: [
            Applicable(
                name: "LTR",
                language: "en",
                stylesheets: .default,
                expected: ["hyphens", "letterSpacing", "ligatures", "paragraphIndent", "textAlign", "textNormalization", "wordSpacing"]
            ),
            Applicable(
                name: "RTL",
                language: "ar",
                stylesheets: .rtl,
                expected: ["ligatures", "paragraphIndent", "textAlign", "wordSpacing"]
            ),
            Applicable(
                name: "CJK horizontal",
                language: "ja",
                stylesheets: .cjkHorizontal,
                expected: ["letterSpacing", "noRuby"]
            ),
            Applicable(
                name: "CJK vertical",
                language: "ja",
                verticalText: true,
                stylesheets: .cjkVertical,
                expected: ["letterSpacing", "noRuby"]
            ),
        ])
        func applicable(_ example: Applicable) {
            let settings = settings(preferences: EPUBPreferences(language: Language(example.language), verticalText: example.verticalText))
            #expect(settings.cssLayout.stylesheets == example.stylesheets)
            #expect(applicableSettings(settings).intersection(languageSpecificSettings) == example.expected)
        }

        @Test("the settings follow a language changed after the resolution")
        func languageChangedAfterResolution() {
            var settings = settings(preferences: EPUBPreferences(language: Language("en")))
            #expect(settings.isApplicable(\.hyphens))

            settings.language = Language("ja")
            #expect(settings.cssLayout.stylesheets == .cjkHorizontal)
            #expect(applicableSettings(settings).intersection(languageSpecificSettings) == ["letterSpacing", "noRuby"])
        }
    }

    @Suite("columnCount") struct ColumnCount {
        @Test("preferences ignore values lower than 1", arguments: [0, -1])
        func preferencesIgnoreInvalidValues(value: Int) {
            #expect(EPUBPreferences(columnCount: value).columnCount == nil)
        }

        @Test("defaults ignore values lower than 1", arguments: [0, -1])
        func defaultsIgnoreInvalidValues(value: Int) {
            #expect(EPUBDefaults(columnCount: value).columnCount == nil)
        }

        @Test("valid values are kept", arguments: [1, 2, 3])
        func validValues(value: Int) {
            #expect(EPUBPreferences(columnCount: value).columnCount == value)
            #expect(EPUBDefaults(columnCount: value).columnCount == value)
        }
    }

    @Suite("scroll") struct Scroll {
        @Test("vertical text is always scrolled, so the setting doesn't apply")
        func verticalText() {
            let settings = settings(preferences: EPUBPreferences(scroll: false, verticalText: true))
            #expect(settings.scroll)
            #expect(!settings.isApplicable(\.scroll))
        }
    }

    @Suite("line length") struct LineLength {
        @Test("preferences ignore values lower than or equal to 0", arguments: [0.0, -1.0])
        func preferencesIgnoreInvalidValues(value: Double) {
            let prefs = EPUBPreferences(
                maximalLineLength: value,
                minimalLineLength: value,
                optimalLineLength: value
            )
            #expect(prefs.maximalLineLength == nil)
            #expect(prefs.minimalLineLength == nil)
            #expect(prefs.optimalLineLength == nil)
        }

        @Test("defaults ignore values lower than or equal to 0", arguments: [0.0, -1.0])
        func defaultsIgnoreInvalidValues(value: Double) {
            let defaults = EPUBDefaults(
                maximalLineLength: value,
                minimalLineLength: value,
                optimalLineLength: value
            )
            #expect(defaults.maximalLineLength == nil)
            #expect(defaults.minimalLineLength == nil)
            #expect(defaults.optimalLineLength == nil)
        }

        @Test("the lines are limited by default, unless the defaults remove the limit")
        func maximalLineLengthDefault() {
            #expect(EPUBDefaults().maximalLineLength == 1.0)
            #expect(settings().maximalLineLength == 1.0)

            let defaults = EPUBDefaults(maximalLineLength: nil)
            #expect(settings(defaults: defaults).maximalLineLength == nil)
        }

        struct Applicable: Sendable, CustomTestStringConvertible {
            let name: String
            let preferences: EPUBPreferences
            let expected: Set<String>

            var testDescription: String {
                name
            }
        }

        @Test("the applicable column and line-length settings depend on the columns and the scroll mode", arguments: [
            Applicable(name: "automatic columns", preferences: EPUBPreferences(), expected: ["columnCount", "optimalLineLength", "maximalLineLength"]),
            Applicable(name: "several columns", preferences: EPUBPreferences(columnCount: 2), expected: ["columnCount", "minimalLineLength", "maximalLineLength"]),
            Applicable(name: "one column", preferences: EPUBPreferences(columnCount: 1), expected: ["columnCount", "maximalLineLength"]),
            Applicable(name: "scroll mode", preferences: EPUBPreferences(columnCount: 2, scroll: true), expected: ["maximalLineLength"]),
        ])
        func applicable(_ example: Applicable) {
            let columnsAndLineLengths: Set = ["columnCount", "optimalLineLength", "minimalLineLength", "maximalLineLength"]
            #expect(applicableSettings(settings(preferences: example.preferences)).intersection(columnsAndLineLengths) == example.expected)
        }
    }

    @Suite("fontWeight") struct FontWeight {
        @Test("preferences and defaults limit the value to the supported range", arguments: [
            (-1.0, 0.0),
            (1.5, 1.5),
            (3.0, 2.5),
        ])
        func limitValue(value: Double, expected: Double) {
            #expect(EPUBPreferences(fontWeight: value).fontWeight == expected)
            #expect(EPUBDefaults(fontWeight: value).fontWeight == expected)
        }

        @Test("ReadiumCSS emits the weight as a factor of 400 limited to 1 ... 1000", arguments: [
            (1.0, "400"),
            (0.29, "116"),
            (0.0, "1"),
            (3.0, "1000"),
            (.infinity, "1000"),
            (.nan, nil),
        ] as [(Double?, String?)])
        func css(fontWeight: Double?, expected: String?) {
            // Set on the settings, as the preferences are limited to 2.5.
            var settings = settings()
            settings.fontWeight = fontWeight
            let props = cssProperties(settings)
            #expect(props["--USER__fontWeight"] == .some(expected))
            #expect(props["font-weight"] == nil)
        }
    }

    @Suite("fontWidth") struct FontWidth {
        @Test("preferences and defaults limit the value to the supported range", arguments: [
            (0.2, 0.5),
            (1.3, 1.3),
            (3.0, 2.5),
        ])
        func limitValue(value: Double, expected: Double) {
            #expect(EPUBPreferences(fontWidth: value).fontWidth == expected)
            #expect(EPUBDefaults(fontWidth: value).fontWidth == expected)
        }
    }

    @Suite("non-negative values") struct NonNegativeValues {
        @Test("preferences and defaults replace negative values with 0", arguments: [
            (-1.0, 0.0),
            (0.5, 0.5),
        ])
        func limitValues(value: Double, expected: Double) {
            let prefs = EPUBPreferences(letterSpacing: value, pageMargins: value, paragraphSpacing: value, wordSpacing: value)
            #expect(prefs.letterSpacing == expected)
            #expect(prefs.pageMargins == expected)
            #expect(prefs.paragraphSpacing == expected)
            #expect(prefs.wordSpacing == expected)

            let defaults = EPUBDefaults(letterSpacing: value, pageMargins: value, paragraphSpacing: value, wordSpacing: value)
            #expect(defaults.letterSpacing == expected)
            #expect(defaults.pageMargins == expected)
            #expect(defaults.paragraphSpacing == expected)
            #expect(defaults.wordSpacing == expected)
        }

        @Test("preferences and defaults ignore a font size that is not above 0", arguments: [
            (-1.0, nil),
            (0.0, nil),
            (.nan, nil),
            (0.01, 0.01),
            (1.5, 1.5),
        ] as [(Double, Double?)])
        func fontSize(value: Double, expected: Double?) {
            #expect(EPUBPreferences(fontSize: value).fontSize == expected)
            #expect(EPUBDefaults(fontSize: value).fontSize == expected)
        }
    }

    /// The limits of `EPUBPreferences.init` are bypassed by the preferences
    /// set after the initialization, so `EPUBSettings` applies them too.
    @Suite("settings limits") struct SettingsLimits {
        @Test("a preference set after the initialization resolves like one given to the initializer", arguments: limits)
        func preferencesSetAfterInit(limit: Limit) {
            var prefs = EPUBPreferences()
            limit.set(&prefs)
            let resolved = settings(preferences: prefs, defaults: limit.defaults)

            let setting = Mirror(reflecting: resolved).children.first { $0.label == limit.property }
            #expect(setting.map { unwrappedDescription($0.value) } == limit.expected)

            let initialized = prefs.reinitialized()
            #expect(resolved == settings(preferences: initialized, defaults: limit.defaults))
        }

        /// A preference set after the initialization of `EPUBPreferences`, and
        /// the description of the value expected in the resolved setting.
        struct Limit: Sendable, CustomTestStringConvertible {
            let property: String
            let set: @Sendable (inout EPUBPreferences) -> Void
            let defaults: EPUBDefaults
            let expected: String
            let testDescription: String

            init<Value: Sendable>(
                _ keyPath: WritableKeyPath<EPUBPreferences, Value?> & Sendable,
                _ property: String,
                _ value: Value,
                _ expected: String,
                defaults: EPUBDefaults = EPUBDefaults(),
                defaultsDescription: String = "the default EPUBDefaults"
            ) {
                self.property = property
                set = { $0[keyPath: keyPath] = value }
                self.defaults = defaults
                self.expected = expected
                testDescription = "\(property) = \(value) with \(defaultsDescription)"
            }
        }

        static let customDefaults = EPUBDefaults(columnCount: 2, fontSize: 1.4, maximalLineLength: 1.2, minimalLineLength: 0.8, optimalLineLength: 1.5)

        static let limits: [Limit] = [
            // Out of range, falling back on the defaults.
            Limit(\.columnCount, "columnCount", 0, "nil"),
            Limit(\.columnCount, "columnCount", -1, "nil"),
            Limit(\.columnCount, "columnCount", 0, "2", defaults: customDefaults, defaultsDescription: "custom defaults"),
            Limit(\.fontSize, "fontSize", 0, "1.0"),
            Limit(\.fontSize, "fontSize", -1, "1.0"),
            Limit(\.fontSize, "fontSize", .nan, "1.0"),
            Limit(\.fontSize, "fontSize", 0, "1.4", defaults: customDefaults, defaultsDescription: "custom defaults"),
            Limit(\.fontSize, "fontSize", -1, "1.4", defaults: customDefaults, defaultsDescription: "custom defaults"),
            Limit(\.maximalLineLength, "maximalLineLength", 0, "1.0"),
            Limit(\.maximalLineLength, "maximalLineLength", -1, "1.0"),
            Limit(\.maximalLineLength, "maximalLineLength", 0, "1.2", defaults: customDefaults, defaultsDescription: "custom defaults"),
            Limit(\.maximalLineLength, "maximalLineLength", 0, "nil", defaults: EPUBDefaults(maximalLineLength: nil), defaultsDescription: "no default"),
            Limit(\.minimalLineLength, "minimalLineLength", 0, "nil"),
            Limit(\.minimalLineLength, "minimalLineLength", -1, "nil"),
            Limit(\.minimalLineLength, "minimalLineLength", 0, "0.8", defaults: customDefaults, defaultsDescription: "custom defaults"),
            Limit(\.optimalLineLength, "optimalLineLength", 0, "1.0"),
            Limit(\.optimalLineLength, "optimalLineLength", -1, "1.0"),
            Limit(\.optimalLineLength, "optimalLineLength", 0, "1.5", defaults: customDefaults, defaultsDescription: "custom defaults"),

            // Out of range, limited.
            Limit(\.fontWeight, "fontWeight", -1, "0.0"),
            Limit(\.fontWeight, "fontWeight", 3, "2.5"),
            Limit(\.fontWidth, "fontWidth", 0.1, "0.5"),
            Limit(\.fontWidth, "fontWidth", 3, "2.5"),
            Limit(\.darkenImages, "darkenImages", -0.5, "0.0"),
            Limit(\.darkenImages, "darkenImages", 1.5, "1.0"),
            Limit(\.letterSpacing, "letterSpacing", -1, "0.0"),
            Limit(\.pageMargins, "pageMargins", -1, "0.0"),
            Limit(\.paragraphSpacing, "paragraphSpacing", -1, "0.0"),
            Limit(\.wordSpacing, "wordSpacing", -1, "0.0"),

            // Valid values are kept.
            Limit(\.columnCount, "columnCount", 1, "1"),
            Limit(\.columnCount, "columnCount", 1, "1", defaults: customDefaults, defaultsDescription: "custom defaults"),
            Limit(\.fontSize, "fontSize", 0.01, "0.01"),
            Limit(\.fontSize, "fontSize", 2, "2.0"),
            Limit(\.fontSize, "fontSize", 2, "2.0", defaults: customDefaults, defaultsDescription: "custom defaults"),
            Limit(\.fontWeight, "fontWeight", 2.5, "2.5"),
            Limit(\.fontWidth, "fontWidth", 0.5, "0.5"),
            Limit(\.darkenImages, "darkenImages", 0.4, "0.4"),
            Limit(\.letterSpacing, "letterSpacing", 0.2, "0.2"),
            Limit(\.maximalLineLength, "maximalLineLength", 0.01, "0.01"),
            Limit(\.minimalLineLength, "minimalLineLength", 1.5, "1.5"),
            Limit(\.minimalLineLength, "minimalLineLength", 1.5, "1.5", defaults: customDefaults, defaultsDescription: "custom defaults"),
            Limit(\.optimalLineLength, "optimalLineLength", 1.2, "1.2", defaults: customDefaults, defaultsDescription: "custom defaults"),
            Limit(\.pageMargins, "pageMargins", 0, "0.0"),
            Limit(\.paragraphSpacing, "paragraphSpacing", 0.5, "0.5"),
            Limit(\.wordSpacing, "wordSpacing", 0.3, "0.3"),
        ]

        @Test("the settings limit the defaults set after their initialization")
        func defaultsSetAfterInit() {
            var defaults = EPUBDefaults()
            defaults.columnCount = 0
            defaults.fontSize = -1
            defaults.fontWeight = 3
            defaults.fontWidth = 0.1
            defaults.letterSpacing = -1
            defaults.maximalLineLength = 0
            defaults.minimalLineLength = -1
            defaults.optimalLineLength = 0
            defaults.pageMargins = -1
            defaults.paragraphSpacing = -1
            defaults.wordSpacing = -1

            let settings = settings(defaults: defaults)
            #expect(settings.columnCount == nil)
            #expect(settings.fontSize == 1.0)
            #expect(settings.fontWeight == 2.5)
            #expect(settings.fontWidth == 0.5)
            #expect(settings.letterSpacing == 0)
            #expect(settings.maximalLineLength == nil)
            #expect(settings.minimalLineLength == nil)
            #expect(settings.optimalLineLength == 1.0)
            #expect(settings.pageMargins == 0)
            #expect(settings.paragraphSpacing == 0)
            #expect(settings.wordSpacing == 0)
        }

        @Test("settings created directly are limited")
        func settingsCreatedDirectly() {
            let settings = makeSettings(
                columnCount: -1,
                fontSize: -1,
                fontWeight: -1,
                fontWidth: 3,
                darkenImages: 1.5,
                letterSpacing: -1,
                maximalLineLength: -1,
                minimalLineLength: 0,
                optimalLineLength: -1,
                pageMargins: -1,
                paragraphSpacing: -1,
                wordSpacing: -1
            )
            #expect(settings == makeSettings(
                columnCount: nil,
                fontSize: 1.0,
                fontWeight: 0,
                fontWidth: 2.5,
                darkenImages: 1,
                letterSpacing: 0,
                maximalLineLength: nil,
                minimalLineLength: nil,
                optimalLineLength: 1.0,
                pageMargins: 0,
                paragraphSpacing: 0,
                wordSpacing: 0
            ))
        }

        @Test("settings created directly keep the valid values")
        func settingsCreatedDirectlyWithValidValues() {
            let settings = makeSettings(
                columnCount: 3,
                fontSize: 0.01,
                fontWeight: 2.5,
                fontWidth: 0.5,
                darkenImages: 0,
                letterSpacing: 0.2,
                maximalLineLength: 2,
                minimalLineLength: 0.01,
                optimalLineLength: 1.5,
                pageMargins: 0,
                paragraphSpacing: 0.5,
                wordSpacing: 0.3
            )
            #expect(settings.columnCount == 3)
            #expect(settings.fontSize == 0.01)
            #expect(settings.fontWeight == 2.5)
            #expect(settings.fontWidth == 0.5)
            #expect(settings.darkenImages == 0)
            #expect(settings.letterSpacing == 0.2)
            #expect(settings.maximalLineLength == 2)
            #expect(settings.minimalLineLength == 0.01)
            #expect(settings.optimalLineLength == 1.5)
            #expect(settings.pageMargins == 0)
            #expect(settings.paragraphSpacing == 0.5)
            #expect(settings.wordSpacing == 0.3)
        }

        private func makeSettings(
            columnCount: Int?,
            fontSize: Double,
            fontWeight: Double?,
            fontWidth: Double?,
            darkenImages: Double?,
            letterSpacing: Double?,
            maximalLineLength: Double?,
            minimalLineLength: Double?,
            optimalLineLength: Double,
            pageMargins: Double,
            paragraphSpacing: Double?,
            wordSpacing: Double?
        ) -> EPUBSettings {
            EPUBSettings(
                backgroundColor: nil,
                blendImages: false,
                columnCount: columnCount,
                darkenImages: darkenImages,
                fit: .auto,
                fontFamily: nil,
                fontSize: fontSize,
                fontWeight: fontWeight,
                fontWidth: fontWidth,
                hyphens: nil,
                invertGaiji: false,
                invertImages: false,
                language: nil,
                letterSpacing: letterSpacing,
                ligatures: nil,
                lineHeight: nil,
                linkColor: nil,
                maximalLineLength: maximalLineLength,
                minimalLineLength: minimalLineLength,
                noRuby: false,
                offsetFirstPage: nil,
                optimalLineLength: optimalLineLength,
                pageMargins: pageMargins,
                paragraphIndent: nil,
                paragraphSpacing: paragraphSpacing,
                readingProgression: .ltr,
                scroll: false,
                spread: .auto,
                textAlign: nil,
                textColor: nil,
                textNormalization: false,
                verticalText: false,
                visitedColor: nil,
                wordSpacing: wordSpacing
            )
        }
    }

    @Suite("hyphens") struct Hyphens {
        @Test("the setting applies with a justified text")
        func appliesWithJustifiedText() {
            #expect(settings(preferences: EPUBPreferences(textAlign: .justify)).isApplicable(\.hyphens))
        }
    }

    @Suite("image filters") struct ImageFilters {
        @Test("preferences limit darkenImages to 0.0 ... 1.0", arguments: [
            (-0.5, 0.0),
            (0.0, 0.0),
            (0.4, 0.4),
            (1.0, 1.0),
            (1.5, 1.0),
        ])
        func limitValue(value: Double, expected: Double) {
            let prefs = EPUBPreferences(darkenImages: value)
            #expect(prefs.darkenImages == expected)
        }

        @Test("preferences keep unset image filters unset")
        func unsetValue() {
            let prefs = EPUBPreferences()
            #expect(prefs.darkenImages == nil)
            #expect(prefs.invertImages == nil)
            #expect(prefs.invertGaiji == nil)
        }

        @Test("ReadiumCSS doesn't apply the image filters which are off", arguments: [0.0, -0.5])
        func cssImageFiltersOff(value: Double) {
            let props = cssProperties(preferences: EPUBPreferences(darkenImages: value, invertGaiji: false, invertImages: false))
            #expect(props["--USER__darkenImages"] == .some(nil))
            #expect(props["--USER__invertImages"] == .some(nil))
            #expect(props["--USER__invertGaiji"] == .some(nil))
        }

        @Test("ReadiumCSS inverts at 100% when the inversions are on")
        func cssInversionsOn() {
            let props = cssProperties(preferences: EPUBPreferences(invertGaiji: true, invertImages: true))
            #expect(props["--USER__invertImages"] == "1.00000")
            #expect(props["--USER__invertGaiji"] == "1.00000")
        }

        @Test("ReadiumCSS emits darkenImages set after the initialization up to 100%")
        func cssImageFiltersAboveMaximum() {
            // Set after the initialization, which doesn't limit it.
            var prefs = EPUBPreferences()
            prefs.darkenImages = 1.5
            let props = cssProperties(preferences: prefs)
            #expect(props["--USER__darkenImages"] == "0.00000")
        }

        // `--USER__invertGaiji: 0` would replace the whole `filter` of the
        // gaiji, which would not be filtered with the other images.
        @Test("ReadiumCSS keeps the other filters on the gaiji when invertGaiji is off")
        func cssInvertGaijiOff() {
            let props = cssProperties(preferences: EPUBPreferences(darkenImages: 0.2, invertGaiji: false, invertImages: true))
            #expect(props["--USER__darkenImages"] == "0.80000")
            #expect(props["--USER__invertImages"] == "1.00000")
            #expect(props["--USER__invertGaiji"] == .some(nil))
        }

        /// Repeated steps of 0.1 down to 0% leave a residue instead of an
        /// exact 0.
        @Test("ReadiumCSS doesn't darken the images with a residue above 0%", arguments: [1e-16, 0.000001])
        func cssDarkenImagesResidue(value: Double) {
            #expect(cssProperties(preferences: EPUBPreferences(darkenImages: value))["--USER__darkenImages"] == .some(nil))
        }
    }

    @Suite("colors") struct Colors {
        private let red = Color(rawValue: 0xFF0000)

        @Test("the effective background color is white when unset")
        func effectiveBackgroundColor() {
            #expect(settings().effectiveBackgroundColor == Color(rawValue: 0xFFFFFF))
            #expect(settings(preferences: EPUBPreferences(backgroundColor: red)).effectiveBackgroundColor == red)
        }

        @Test("a color is dark according to its luma", arguments: [
            (0x000000, true),
            (0x121212, true),
            (0x0000FF, true),
            (0x7F7F7F, true),
            (0x808080, false),
            (0xFAF4E8, false),
            (0xFFFF00, false),
            (0xFFFFFF, false),
        ])
        func isDark(color: Int, expected: Bool) {
            #expect(Color(rawValue: color).isDark == expected)
        }
    }

    /// These tests write to `UserDefaults.standard`, so they must not run
    /// concurrently.
    @Suite("Legacy preferences", .serialized) struct Legacy {
        private let columnCountKey = "--USER__colCount"
        private let appearanceKey = "--USER__appearance"

        @Test("migrates the column count", arguments: [
            // .auto is not a valid spread preference.
            (0, nil, nil),
            (1, 1, .never),
            (2, 2, .always),
        ] as [(Int, Int?, Spread?)])
        func columnCount(index: Int, columnCount: Int?, spread: Spread?) {
            let prefs = withLegacyValues([columnCountKey: index]) {
                EPUBPreferences.fromLegacyPreferences()
            }
            #expect(prefs.columnCount == columnCount)
            #expect(prefs.spread == spread)
        }

        @Test("migrates the default appearance to no colors")
        func appearanceDefault() {
            let prefs = withLegacyValues([appearanceKey: 0]) {
                EPUBPreferences.fromLegacyPreferences()
            }
            #expect(prefs == EPUBPreferences())
        }

        @Test("migrates the sepia appearance to its colors")
        func appearanceSepia() {
            let prefs = withLegacyValues([appearanceKey: 1]) {
                EPUBPreferences.fromLegacyPreferences()
            }
            #expect(prefs == EPUBPreferences(
                backgroundColor: Color(rawValue: 0xFAF4E8),
                textColor: Color(rawValue: 0x121212)
            ))
        }

        @Test("migrates the night appearance to its colors")
        func appearanceNight() {
            let prefs = withLegacyValues([appearanceKey: 2]) {
                EPUBPreferences.fromLegacyPreferences()
            }
            #expect(prefs == EPUBPreferences(
                backgroundColor: Color(rawValue: 0x000000),
                invertGaiji: true,
                linkColor: Color(rawValue: 0x63CAFF),
                textColor: Color(rawValue: 0xFEFEFE),
                visitedColor: Color(rawValue: 0x0099E5)
            ))
        }

        @Test("the legacy colors take precedence over the appearance colors")
        func appearanceWithExplicitColors() {
            let night = withLegacyValues([
                appearanceKey: 2,
                "--USER__textColor": "#FF0000",
            ]) {
                EPUBPreferences.fromLegacyPreferences()
            }
            #expect(night == EPUBPreferences(
                backgroundColor: Color(rawValue: 0x000000),
                invertGaiji: true,
                linkColor: Color(rawValue: 0x63CAFF),
                textColor: Color(rawValue: 0xFF0000),
                visitedColor: Color(rawValue: 0x0099E5)
            ))

            let sepia = withLegacyValues([
                appearanceKey: 1,
                "--USER__backgroundColor": "#00FF00",
            ]) {
                EPUBPreferences.fromLegacyPreferences()
            }
            #expect(sepia == EPUBPreferences(
                backgroundColor: Color(rawValue: 0x00FF00),
                textColor: Color(rawValue: 0x121212)
            ))
        }

        @Test("migrates the appearance with custom appearance values")
        func appearanceCustomValues() {
            let prefs = withLegacyValues([appearanceKey: 0]) {
                EPUBPreferences.fromLegacyPreferences(appearanceValues: ["readium-night-on", "readium-default-on"])
            }
            #expect(prefs.backgroundColor == Color(rawValue: 0x000000))
        }

        @Test("drops the settings ignored with the 2.x publisher defaults")
        func publisherDefaultsOn() {
            let prefs = withLegacyValues(publisherDefaultsValues(publisherDefaults: true)) {
                EPUBPreferences.fromLegacyPreferences()
            }
            #expect(prefs == EPUBPreferences(fontSize: 1.2))
        }

        @Test("keeps the settings when the 2.x publisher defaults are off or unset", arguments: [false, nil])
        func publisherDefaultsOffOrUnset(publisherDefaults: Bool?) {
            let prefs = withLegacyValues(publisherDefaultsValues(publisherDefaults: publisherDefaults)) {
                EPUBPreferences.fromLegacyPreferences()
            }
            #expect(prefs == EPUBPreferences(
                fontSize: 1.2,
                hyphens: false,
                letterSpacing: 0.1,
                lineHeight: 1.5,
                paragraphSpacing: 0.5,
                textAlign: .justify,
                wordSpacing: 0.2
            ))
        }

        /// Values saved by the 2.x toolkit, including the settings ignored
        /// while the publisher defaults were enabled.
        private func publisherDefaultsValues(publisherDefaults: Bool?) -> [String: Any] {
            var values: [String: Any] = [
                "--USER__fontSize": 120.0,
                "--USER__bodyHyphens": false,
                "--USER__letterSpacing": 0.1,
                "--USER__lineHeight": 1.5,
                "--USER__paraSpacing": 0.5,
                "--USER__textAlign": 0,
                "--USER__wordSpacing": 0.2,
            ]
            if let publisherDefaults {
                values["--USER__advancedSettings"] = publisherDefaults
            }
            return values
        }

        private func withLegacyValues<T>(_ values: [String: Any], _ block: () -> T) -> T {
            let defaults = UserDefaults.standard
            for (key, value) in values {
                defaults.set(value, forKey: key)
            }
            defer {
                for key in values.keys {
                    defaults.removeObject(forKey: key)
                }
            }
            return block()
        }
    }
}

/// Every preference set to a value different from the ones of `allDefaults`.
private let otherPreferences = EPUBPreferences(
    backgroundColor: Color(hex: "#00FFFF"),
    blendImages: false,
    columnCount: 1,
    darkenImages: 0.7,
    fit: .auto,
    fontFamily: "Iowan Old Style",
    fontSize: 0.9,
    fontWeight: 0.5,
    fontWidth: 0.8,
    hyphens: false,
    invertGaiji: false,
    invertImages: true,
    language: Language("de"),
    letterSpacing: 0.3,
    ligatures: true,
    lineHeight: 1.1,
    linkColor: Color(hex: "#FFFF00"),
    maximalLineLength: 1.9,
    minimalLineLength: 0.6,
    noRuby: false,
    offsetFirstPage: false,
    optimalLineLength: 0.7,
    pageMargins: 0.5,
    paragraphIndent: 2.0,
    paragraphSpacing: 1.0,
    readingProgression: .ltr,
    scroll: false,
    spread: .never,
    textAlign: .left,
    textColor: Color(hex: "#000000"),
    textNormalization: false,
    verticalText: false,
    visitedColor: Color(hex: "#FFFFFF"),
    wordSpacing: 0.6
)

/// Every default set to a value different from the fallback of the settings
/// and from `otherPreferences`.
private let allDefaults = EPUBDefaults(
    columnCount: 2,
    fit: .page,
    fontSize: 1.3,
    fontWeight: 1.25,
    fontWidth: 1.4,
    hyphens: true,
    language: Language("it"),
    letterSpacing: 0.4,
    ligatures: false,
    lineHeight: 1.7,
    maximalLineLength: 1.6,
    minimalLineLength: 0.9,
    noRuby: true,
    offsetFirstPage: true,
    optimalLineLength: 1.1,
    pageMargins: 2.5,
    paragraphIndent: 0.6,
    paragraphSpacing: 0.7,
    readingProgression: .rtl,
    scroll: true,
    spread: .always,
    textAlign: .right,
    textNormalization: true,
    wordSpacing: 0.8
)

/// Preferences resolved to optional settings, which are `nil` when unset.
private let optionalPreferences = EPUBPreferences(
    backgroundColor: Color(rawValue: 0xFF0000),
    fontWeight: 1.5,
    fontWidth: 1.5,
    hyphens: true,
    letterSpacing: 0.1,
    ligatures: true,
    lineHeight: 1.6,
    linkColor: Color(rawValue: 0x00FF00),
    paragraphIndent: 1.0,
    paragraphSpacing: 0.5,
    textAlign: .left,
    textColor: Color(rawValue: 0x0000FF),
    visitedColor: Color(rawValue: 0xFFFF00),
    wordSpacing: 0.1
)

/// Readium CSS properties emitted for each preference, which differ from the
/// ones emitted when every preference is unset.
///
/// The layout preferences are emitted once the layout is resolved (see
/// `ReadiumCSSTests`), and the fixed-layout preferences are not emitted.
private let cssTable: [(preferences: EPUBPreferences, expected: [String: String?])] = [
    (EPUBPreferences(backgroundColor: Color(rawValue: 0xFF0000)), ["--USER__backgroundColor": "#FF0000"]),
    (EPUBPreferences(blendImages: true), ["--USER__blendImages": "readium-blend-on"]),
    (EPUBPreferences(columnCount: 2), [:]),
    (EPUBPreferences(darkenImages: 0.2), ["--USER__darkenImages": "0.80000"]),
    (EPUBPreferences(fit: .width), [:]),
    (EPUBPreferences(fontFamily: "Literata"), ["--USER__fontFamily": "Literata"]),
    (EPUBPreferences(fontSize: 1.5), ["--USER__fontSize": "150.00000%"]),
    (EPUBPreferences(fontWeight: 1.5), ["--USER__fontWeight": "600"]),
    (EPUBPreferences(fontWidth: 1.5), ["--USER__fontWidth": "150.00000%"]),
    (EPUBPreferences(hyphens: true), ["--USER__bodyHyphens": "auto"]),
    (EPUBPreferences(hyphens: false), ["--USER__bodyHyphens": "none"]),
    (EPUBPreferences(invertGaiji: true), ["--USER__invertGaiji": "1.00000"]),
    (EPUBPreferences(invertImages: true), ["--USER__invertImages": "1.00000"]),
    (EPUBPreferences(language: Language("fr")), [:]),
    (EPUBPreferences(letterSpacing: 0.2), ["--USER__letterSpacing": "0.20000rem"]),
    (EPUBPreferences(ligatures: true), ["--USER__ligatures": "common-ligatures"]),
    (EPUBPreferences(ligatures: false), ["--USER__ligatures": "none"]),
    (EPUBPreferences(lineHeight: 1.6), ["--USER__lineHeight": "1.60000"]),
    (EPUBPreferences(linkColor: Color(rawValue: 0x00FF00)), ["--USER__linkColor": "#00FF00"]),
    (EPUBPreferences(maximalLineLength: 1.2), [:]),
    (EPUBPreferences(minimalLineLength: 0.8), [:]),
    (EPUBPreferences(noRuby: true), ["--USER__noRuby": "readium-noRuby-on"]),
    (EPUBPreferences(offsetFirstPage: true), [:]),
    (EPUBPreferences(optimalLineLength: 1.2), [:]),
    (EPUBPreferences(pageMargins: 1.5), [:]),
    (EPUBPreferences(paragraphIndent: 1.2), ["--USER__paraIndent": "1.20000rem"]),
    (EPUBPreferences(paragraphSpacing: 0.5), ["--USER__paraSpacing": "0.50000rem"]),
    (EPUBPreferences(readingProgression: .rtl), [:]),
    (EPUBPreferences(scroll: true), ["--USER__view": "readium-scroll-on"]),
    (EPUBPreferences(spread: .always), [:]),
    (EPUBPreferences(textAlign: .justify), ["--USER__textAlign": "justify"]),
    (EPUBPreferences(textAlign: .left), ["--USER__textAlign": "left"]),
    (EPUBPreferences(textAlign: .right), ["--USER__textAlign": "right"]),
    (EPUBPreferences(textAlign: .start), ["--USER__textAlign": "start"]),
    (EPUBPreferences(textAlign: .center), ["--USER__textAlign": "start"]),
    (EPUBPreferences(textAlign: .end), ["--USER__textAlign": "start"]),
    (EPUBPreferences(textColor: Color(rawValue: 0x0000FF)), ["--USER__textColor": "#0000FF"]),
    (EPUBPreferences(textNormalization: true), ["--USER__a11yNormalize": "readium-a11y-on"]),
    // Vertical text is always scrolled.
    (EPUBPreferences(verticalText: true), ["--USER__view": "readium-scroll-on"]),
    (EPUBPreferences(visitedColor: Color(rawValue: 0xFFFF00)), ["--USER__visitedColor": "#FFFF00"]),
    (EPUBPreferences(wordSpacing: 0.2), ["--USER__wordSpacing": "0.20000rem"]),
]

/// Names of the stored properties of `EPUBPreferences`.
private let allPreferenceNames = Set(Mirror(reflecting: EPUBPreferences()).children.compactMap(\.label))

/// Names of the stored properties of `value` which are `nil`.
private func unsetProperties(of value: Any) -> Set<String> {
    Set(
        Mirror(reflecting: value).children
            .filter { child in
                let value = Mirror(reflecting: child.value)
                return value.displayStyle == .optional && value.children.isEmpty
            }
            .map { $0.label ?? "?" }
    )
}

/// Description of `value`, without its `Optional` wrapper.
private func unwrappedDescription(_ value: Any) -> String {
    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional, let wrapped = mirror.children.first {
        return unwrappedDescription(wrapped.value)
    }
    return String(describing: value)
}

private func settings(
    preferences: EPUBPreferences = EPUBPreferences(),
    defaults: EPUBDefaults = EPUBDefaults(),
    layout: Layout? = nil,
    readingOrder: [Link] = [Link(href: "c1.xhtml", mediaType: .xhtml)]
) -> EPUBSettings {
    let metadata = Metadata(title: "Test", layout: layout)
    return EPUBSettings(
        preferences: preferences,
        defaults: defaults,
        metadata: metadata,
        layouts: EPUBLayouts(readingOrder: readingOrder, metadata: metadata)
    )
}

/// Readium CSS properties emitted for the given `settings`, before the layout
/// is resolved, without any WebKit patch.
private func cssProperties(_ settings: EPUBSettings) -> [String: String?] {
    var css = ReadiumCSS(baseURL: HTTPURL(string: "https://readium/")!)
    css.update(with: settings, userInterfaceIdiom: .mac)
    return css.rsProperties.cssProperties()
        .merging(css.userProperties.cssProperties()) { _, user in user }
}

private func cssProperties(
    preferences: EPUBPreferences = EPUBPreferences(),
    defaults: EPUBDefaults = EPUBDefaults()
) -> [String: String?] {
    cssProperties(settings(preferences: preferences, defaults: defaults))
}

/// Names of the settings which apply.
private func applicableSettings(_ settings: EPUBSettings) -> Set<String> {
    Set(allSettings.filter { settings.isApplicable($0.keyPath) }.map(\.name))
}

/// Every setting of `EPUBSettings`, with its name.
private var allSettings: [(name: String, keyPath: PartialKeyPath<EPUBSettings>)] {
    [
        ("backgroundColor", \.backgroundColor),
        ("blendImages", \.blendImages),
        ("columnCount", \.columnCount),
        ("darkenImages", \.darkenImages),
        ("fit", \.fit),
        ("fontFamily", \.fontFamily),
        ("fontSize", \.fontSize),
        ("fontWeight", \.fontWeight),
        ("fontWidth", \.fontWidth),
        ("hyphens", \.hyphens),
        ("invertGaiji", \.invertGaiji),
        ("invertImages", \.invertImages),
        ("language", \.language),
        ("letterSpacing", \.letterSpacing),
        ("ligatures", \.ligatures),
        ("lineHeight", \.lineHeight),
        ("linkColor", \.linkColor),
        ("maximalLineLength", \.maximalLineLength),
        ("minimalLineLength", \.minimalLineLength),
        ("noRuby", \.noRuby),
        ("offsetFirstPage", \.offsetFirstPage),
        ("optimalLineLength", \.optimalLineLength),
        ("pageMargins", \.pageMargins),
        ("paragraphIndent", \.paragraphIndent),
        ("paragraphSpacing", \.paragraphSpacing),
        ("readingProgression", \.readingProgression),
        ("scroll", \.scroll),
        ("spread", \.spread),
        ("textAlign", \.textAlign),
        ("textColor", \.textColor),
        ("textNormalization", \.textNormalization),
        ("verticalText", \.verticalText),
        ("visitedColor", \.visitedColor),
        ("wordSpacing", \.wordSpacing),
    ]
}

private extension EPUBPreferences {
    /// Returns a copy of the preferences, created with the initializer.
    func reinitialized() -> EPUBPreferences {
        EPUBPreferences(
            backgroundColor: backgroundColor,
            blendImages: blendImages,
            columnCount: columnCount,
            darkenImages: darkenImages,
            fit: fit,
            fontFamily: fontFamily,
            fontSize: fontSize,
            fontWeight: fontWeight,
            fontWidth: fontWidth,
            hyphens: hyphens,
            invertGaiji: invertGaiji,
            invertImages: invertImages,
            language: language,
            letterSpacing: letterSpacing,
            ligatures: ligatures,
            lineHeight: lineHeight,
            linkColor: linkColor,
            maximalLineLength: maximalLineLength,
            minimalLineLength: minimalLineLength,
            noRuby: noRuby,
            offsetFirstPage: offsetFirstPage,
            optimalLineLength: optimalLineLength,
            pageMargins: pageMargins,
            paragraphIndent: paragraphIndent,
            paragraphSpacing: paragraphSpacing,
            readingProgression: readingProgression,
            scroll: scroll,
            spread: spread,
            textAlign: textAlign,
            textColor: textColor,
            textNormalization: textNormalization,
            verticalText: verticalText,
            visitedColor: visitedColor,
            wordSpacing: wordSpacing
        )
    }
}
