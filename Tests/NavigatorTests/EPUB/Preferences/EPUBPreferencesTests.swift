//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumNavigator
import ReadiumShared
import Testing

enum EPUBPreferencesTests {
    /// Keeps the round-trip, merging and settings tests exhaustive.
    ///
    /// A stored property missing from the `Codable` implementation, from
    /// `merging(_:)` or from the settings resolution would still pass these
    /// tests if the fixtures left it `nil`, or gave it the value it is compared
    /// with. These tests list the stored properties with a `Mirror`, so they
    /// fail as soon as a new property is added to `EPUBPreferences` or
    /// `EPUBDefaults` without being set in the fixtures.
    @Suite("fixtures") struct Fixtures {
        @Test("the fixtures set every property")
        func complete() {
            #expect(unsetProperties(of: allPreferences) == [])
            #expect(unsetProperties(of: otherPreferences) == [])
            #expect(unsetProperties(of: allDefaults) == [])
        }

        @Test("the fixtures compared by the tests have a different value for every property")
        func distinct() {
            #expect(sameProperties(allPreferences, otherPreferences) == [])
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
        @Test("the settings when every preference and default is unset")
        func unset() {
            #expect(settings() == EPUBSettings(
                backgroundColor: nil,
                columnCount: nil,
                fit: .auto,
                fontFamily: nil,
                fontSize: 1.0,
                fontWeight: nil,
                fontWidth: nil,
                hyphens: nil,
                blendImages: false,
                darkenImages: nil,
                invertImages: nil,
                invertGaiji: nil,
                language: nil,
                letterSpacing: nil,
                ligatures: nil,
                lineHeight: nil,
                linkColor: nil,
                maximalLineLength: nil,
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
        @MainActor func unset() {
            // The WebKit patches depend on the device running the tests.
            let props = cssProperties()
                .compactMapValues { $0 }
                .filter { !$0.key.hasSuffix("Patch") }
            #expect(props == [
                "--RS__disableOverflow": "readium-noOverflow-on",
                "--USER__fontSize": "100.00000%",
                "--USER__view": "readium-paged-on",
            ])
        }

        @Test("emits each preference", arguments: cssTable)
        @MainActor func emitted(preferences: EPUBPreferences, expected: [String: String?]) {
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
            let merged = cssTable
                .map(\.preferences)
                .reduce(EPUBPreferences()) { $0.merging($1) }
            #expect(unsetProperties(of: merged) == [])
        }
    }

    /// Which editor preferences are effective, depending on the layouts of
    /// the reading order resources and on the preferences which are set.
    @Suite("effective preferences") struct EffectivePreferences {
        private let fixedLayoutPreferences: Set<String> = ["fit", "offsetFirstPage", "spread"]
        private let layoutIndependentPreferences: Set<String> = ["backgroundColor", "language", "readingProgression"]

        @Test("the tests list every preference")
        @MainActor func listsEveryPreference() {
            let editor = makeEditor()
            #expect(Set(editorPreferences(of: editor).map(\.name)) == allPreferenceNames)
        }

        @Test("every preference is effective in a reflowable publication, except the fixed-layout ones and the ones depending on the language or the columns")
        @MainActor func reflowablePublication() {
            let editor = makeEditor(preferences: setOnlyPreferences)
            #expect(
                effectivePreferences(of: editor) == allPreferenceNames
                    .subtracting(fixedLayoutPreferences)
                    // Effective only with a CJK language, and with several columns.
                    .subtracting(["noRuby", "minimalLineLength"])
            )
        }

        @Test("the preferences of both layouts are effective in a fixed-layout publication containing a reflowable resource", arguments: ["en", "ja"])
        @MainActor func fixedLayoutPublicationWithReflowableResource(language: String) {
            var preferences = setOnlyPreferences
            preferences.language = Language(code: .bcp47(language))

            var reflowable = Link(href: "c2.xhtml", mediaType: .xhtml)
            reflowable.properties.epubLayout = .reflowable

            let editor = makeEditor(
                preferences: preferences,
                layout: .fixed,
                readingOrder: [Link(href: "c1.xhtml", mediaType: .xhtml), reflowable]
            )
            let reflowableEditor = makeEditor(preferences: preferences)
            #expect(editor.defaultLayout == .fixed)
            #expect(
                effectivePreferences(of: editor)
                    == effectivePreferences(of: reflowableEditor).union(fixedLayoutPreferences)
            )
        }

        @Test("only the fixed-layout preferences are effective in a fixed-layout publication")
        @MainActor func fixedLayoutPublication() {
            let editor = makeEditor(preferences: setOnlyPreferences, layout: .fixed)
            #expect(effectivePreferences(of: editor) == fixedLayoutPreferences.union(layoutIndependentPreferences))
        }

        @Test("only the fixed-layout preferences are effective in a reflowable publication containing only fixed-layout resources")
        @MainActor func reflowablePublicationWithoutReflowableResource() {
            var fixed = Link(href: "c1.xhtml", mediaType: .xhtml)
            fixed.properties.epubLayout = .fixed

            let editor = makeEditor(
                preferences: setOnlyPreferences,
                readingOrder: [
                    fixed,
                    Link(href: "p2.jpg", mediaType: .jpeg),
                    Link(href: "p3.svg", mediaType: .svg),
                ]
            )
            #expect(editor.defaultLayout == .reflowable)
            #expect(effectivePreferences(of: editor) == fixedLayoutPreferences.union(layoutIndependentPreferences))
        }

        @Test("some preferences are effective only when set")
        @MainActor func effectiveOnlyWhenSet() {
            let unsetEditor = makeEditor()
            let setEditor = makeEditor(preferences: setOnlyPreferences)
            let setOnly = allPreferenceNames.subtracting(unsetProperties(of: setOnlyPreferences))
            #expect(effectivePreferences(of: unsetEditor) == effectivePreferences(of: setEditor).subtracting(setOnly))
        }
    }

    @Suite("language-specific preferences") struct LanguageSpecific {
        private let languageSpecificPreferences: Set<String> = [
            "hyphens", "letterSpacing", "ligatures", "noRuby", "paragraphIndent", "textAlign", "wordSpacing",
        ]

        @Test("the editor preferences are effective with the stylesheets supporting them", arguments: [
            ("en", false, CSSLayout.Stylesheets.default, ["hyphens", "letterSpacing", "ligatures", "paragraphIndent", "textAlign", "wordSpacing"]),
            ("ar", false, CSSLayout.Stylesheets.rtl, ["ligatures", "paragraphIndent", "textAlign", "wordSpacing"]),
            ("ja", false, CSSLayout.Stylesheets.cjkHorizontal, ["letterSpacing", "noRuby"]),
            ("ja", true, CSSLayout.Stylesheets.cjkVertical, ["letterSpacing", "noRuby"]),
        ] as [(String, Bool, CSSLayout.Stylesheets, Set<String>)])
        @MainActor func editorEffective(language: String, verticalText: Bool, stylesheets: CSSLayout.Stylesheets, expected: Set<String>) {
            var preferences = setOnlyPreferences
            preferences.language = Language(code: .bcp47(language))
            preferences.verticalText = verticalText
            #expect(settings(preferences: preferences).cssLayout.stylesheets == stylesheets)

            let editor = makeEditor(preferences: preferences)
            #expect(effectivePreferences(of: editor).intersection(languageSpecificPreferences) == expected)
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

        @Test("the editor supports auto, 1 and 2 columns")
        @MainActor func editorSupportedValues() {
            let editor = makeEditor()
            #expect(editor.columnCount.supportedValues == [nil, 1, 2])
            #expect(editor.preferences.columnCount == nil)
            #expect(editor.columnCount.effectiveValue == nil)
        }

        @Test("the editor sets and clears the column count")
        @MainActor func editorSetAndClear() {
            let editor = makeEditor()
            editor.columnCount.set(2)
            #expect(editor.columnCount.value == 2)
            #expect(editor.columnCount.effectiveValue == 2)
            #expect(editor.preferences.columnCount == 2)

            editor.columnCount.clear()
            #expect(editor.preferences.columnCount == nil)
        }

        @Test("the editor uses the defaults as effective value when unset")
        @MainActor func editorEffectiveValueFromDefaults() {
            let editor = makeEditor(defaults: EPUBDefaults(columnCount: 2))
            #expect(editor.columnCount.value == nil)
            #expect(editor.columnCount.effectiveValue == 2)
        }

        @Test("the editor preference is not effective in scroll mode")
        @MainActor func editorNotEffectiveWhenScrolling() {
            let editor = makeEditor(preferences: EPUBPreferences(scroll: true))
            #expect(!editor.columnCount.isEffective)
        }
    }

    @Suite("scroll") struct Scroll {
        @Test("vertical text is always scrolled, so the editor preference is not effective")
        @MainActor func verticalText() {
            let preferences = EPUBPreferences(scroll: false, verticalText: true)
            #expect(settings(preferences: preferences).scroll)

            let editor = makeEditor(preferences: preferences)
            #expect(!editor.scroll.isEffective)
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

        @Test("the editor preferences have the same range, starting from 100%")
        @MainActor func editorRanges() {
            let editor = makeEditor()
            #expect(editor.optimalLineLength.supportedRange == 0.5 ... 2.0)
            #expect(editor.optimalLineLength.effectiveValue == 1.0)
            #expect(editor.minimalLineLength.supportedRange == 0.5 ... 2.0)
            #expect(editor.minimalLineLength.defaultValue == 1.0)
            #expect(editor.minimalLineLength.effectiveValue == nil)
            #expect(editor.maximalLineLength.supportedRange == 0.5 ... 2.0)
            #expect(editor.maximalLineLength.defaultValue == 1.0)
            #expect(editor.maximalLineLength.effectiveValue == nil)
        }

        @Test("the editor sets and clears the line length limits")
        @MainActor func editorSetAndClear() {
            let editor = makeEditor()
            editor.maximalLineLength.increment()
            #expect(editor.preferences.maximalLineLength == 1.1)
            #expect(editor.maximalLineLength.effectiveValue == 1.1)

            editor.maximalLineLength.set(nil)
            #expect(editor.preferences.maximalLineLength == nil)
            #expect(editor.maximalLineLength.effectiveValue == nil)
        }

        @Test("with automatic columns, only the optimal and maximal line lengths are effective")
        @MainActor func editorEffectiveWithAutoColumns() {
            let editor = makeEditor()
            #expect(editor.optimalLineLength.isEffective)
            #expect(!editor.minimalLineLength.isEffective)
            #expect(editor.maximalLineLength.isEffective)
        }

        @Test("with several columns, only the minimal and maximal line lengths are effective")
        @MainActor func editorEffectiveWithSeveralColumns() {
            let editor = makeEditor(preferences: EPUBPreferences(columnCount: 2))
            #expect(!editor.optimalLineLength.isEffective)
            #expect(editor.minimalLineLength.isEffective)
            #expect(editor.maximalLineLength.isEffective)
        }

        @Test("with one column, only the maximal line length is effective")
        @MainActor func editorEffectiveWithOneColumn() {
            let editor = makeEditor(preferences: EPUBPreferences(columnCount: 1))
            #expect(!editor.optimalLineLength.isEffective)
            #expect(!editor.minimalLineLength.isEffective)
            #expect(editor.maximalLineLength.isEffective)
        }

        @Test("in scroll mode, only the maximal line length is effective")
        @MainActor func editorEffectiveWhenScrolling() {
            let editor = makeEditor(preferences: EPUBPreferences(columnCount: 2, scroll: true))
            #expect(!editor.optimalLineLength.isEffective)
            #expect(!editor.minimalLineLength.isEffective)
            #expect(editor.maximalLineLength.isEffective)
        }
    }

    @Suite("lineHeight") struct LineHeight {
        @Test("the editor uses the Readium CSS base line height when unset")
        @MainActor func editorDefaultEffectiveValue() {
            let editor = makeEditor()
            #expect(editor.lineHeight.value == nil)
            #expect(editor.lineHeight.effectiveValue == 1.5)
        }

        @Test("the editor steps from the Readium CSS base line height when unset")
        @MainActor func editorStepsFromDefault() {
            let editor = makeEditor()
            editor.lineHeight.increment()
            #expect(editor.preferences.lineHeight == 1.6)
            #expect(editor.lineHeight.effectiveValue == 1.6)

            editor.lineHeight.clear()
            editor.lineHeight.decrement()
            #expect(editor.preferences.lineHeight == 1.4)
        }

        @Test("the editor uses the defaults as effective value")
        @MainActor func editorEffectiveValueFromDefaults() {
            let editor = makeEditor(defaults: EPUBDefaults(lineHeight: 1.8))
            #expect(editor.preferences.lineHeight == nil)
            #expect(editor.lineHeight.effectiveValue == 1.8)
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

        @Test("the editor steps by 25% from 100%, within 0% and 250%")
        @MainActor func editorSteps() {
            let editor = makeEditor()
            #expect(editor.fontWeight.supportedRange == 0.0 ... 2.5)
            editor.fontWeight.increment()
            #expect(editor.preferences.fontWeight == 1.25)
        }

        @Test("ReadiumCSS emits the weight as a factor of 400 limited to 1 ... 1000", arguments: [
            (1.0, "400"),
            (0.29, "116"),
            (0.0, "1"),
            (3.0, "1000"),
            (.infinity, "1000"),
            (.nan, nil),
        ] as [(Double?, String?)])
        @MainActor func css(fontWeight: Double?, expected: String?) {
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

        @Test("the editor reads 100% when unset, unless the defaults say otherwise", arguments: [
            (nil, 1.0),
            (1.2, 1.2),
        ] as [(Double?, Double)])
        @MainActor func editorEffectiveValue(defaults: Double?, expected: Double) {
            let editor = makeEditor(defaults: EPUBDefaults(fontWidth: defaults))
            #expect(editor.fontWidth.value == nil)
            #expect(editor.fontWidth.effectiveValue == expected)
        }

        @Test("the editor steps by 10% from 100%, within 50% and 250%, and is effective once set")
        @MainActor func editorSteps() {
            let editor = makeEditor()
            #expect(editor.fontWidth.supportedRange == 0.5 ... 2.5)
            #expect(editor.fontWidth.format(value: 1.5) == "150%")
            editor.fontWidth.increment()
            #expect(editor.preferences.fontWidth == 1.1)
            #expect(editor.fontWidth.effectiveValue == 1.1)
            #expect(editor.fontWidth.isEffective)
            editor.fontWidth.clear()
            editor.fontWidth.decrement()
            #expect(editor.preferences.fontWidth == 0.9)
        }
    }

    @Suite("non-negative values") struct NonNegativeValues {
        @Test("preferences and defaults replace negative values with 0", arguments: [
            (-1.0, 0.0),
            (0.5, 0.5),
        ])
        func limitValues(value: Double, expected: Double) {
            let prefs = EPUBPreferences(fontSize: value, letterSpacing: value, pageMargins: value, paragraphSpacing: value, wordSpacing: value)
            #expect(prefs.fontSize == expected)
            #expect(prefs.letterSpacing == expected)
            #expect(prefs.pageMargins == expected)
            #expect(prefs.paragraphSpacing == expected)
            #expect(prefs.wordSpacing == expected)

            let defaults = EPUBDefaults(fontSize: value, letterSpacing: value, pageMargins: value, paragraphSpacing: value, wordSpacing: value)
            #expect(defaults.fontSize == expected)
            #expect(defaults.letterSpacing == expected)
            #expect(defaults.pageMargins == expected)
            #expect(defaults.paragraphSpacing == expected)
            #expect(defaults.wordSpacing == expected)
        }
    }

    @Suite("hyphens") struct Hyphens {
        @Test("the editor reads the hyphens as on when unset, only with justified text", arguments: [
            (.justify, true),
            (.left, false),
        ] as [(TextAlignment?, Bool)])
        @MainActor func editorFollowsJustifiedText(textAlign: TextAlignment?, expected: Bool) {
            let editor = makeEditor(preferences: EPUBPreferences(textAlign: textAlign))
            #expect(editor.hyphens.value == nil)
            #expect(editor.hyphens.effectiveValue == expected)
            #expect(editor.hyphens.isEffective == expected)
        }
    }

    @Suite("ligatures") struct Ligatures {
        @Test("the editor reads the ligatures as on when unset, unless the defaults say otherwise", arguments: [
            (nil, true),
            (false, false),
        ])
        @MainActor func editorEffectiveValue(defaults: Bool?, expected: Bool) {
            let editor = makeEditor(defaults: EPUBDefaults(ligatures: defaults))
            #expect(editor.ligatures.value == nil)
            #expect(editor.ligatures.effectiveValue == expected)
        }
    }

    @Suite("blendImages") struct BlendImages {
        @Test("the editor preference is off when unset")
        @MainActor func editorDefaultEffectiveValue() {
            let editor = makeEditor()
            #expect(editor.blendImages.value == nil)
            #expect(editor.blendImages.effectiveValue == false)
        }

        @Test("the editor sets and clears the preference")
        @MainActor func editorSetAndClear() {
            let editor = makeEditor()
            editor.blendImages.set(true)
            #expect(editor.blendImages.value == true)
            #expect(editor.blendImages.effectiveValue == true)
            #expect(editor.preferences.blendImages == true)

            editor.blendImages.clear()
            #expect(editor.preferences.blendImages == nil)
            #expect(editor.blendImages.effectiveValue == false)

            editor.blendImages.toggle()
            #expect(editor.preferences.blendImages == true)
        }
    }

    @Suite("image filters") struct ImageFilters {
        @Test("ReadiumCSS doesn't apply the image filters at 0 or negative", arguments: [0.0, -0.5])
        @MainActor func cssImageFiltersOff(value: Double) {
            let props = cssProperties(preferences: EPUBPreferences(darkenImages: value, invertImages: value, invertGaiji: value))
            #expect(props["--USER__darkenImages"] == .some(nil))
            #expect(props["--USER__invertImages"] == .some(nil))
            #expect(props["--USER__invertGaiji"] == .some(nil))
        }

        @Test("ReadiumCSS limits the image filters to 100%")
        @MainActor func cssImageFiltersAboveMaximum() {
            let props = cssProperties(preferences: EPUBPreferences(darkenImages: 1.5, invertImages: 1.5, invertGaiji: 1.5))
            #expect(props["--USER__darkenImages"] == "0.00000")
            #expect(props["--USER__invertImages"] == "1.00000")
            #expect(props["--USER__invertGaiji"] == "1.00000")
        }

        // `--USER__invertGaiji: 0` would replace the whole `filter` of the
        // gaiji, which would not be filtered with the other images.
        @Test("ReadiumCSS keeps the other filters on the gaiji when invertGaiji is toggled off")
        @MainActor func cssInvertGaijiToggledOff() {
            let editor = makeEditor(preferences: EPUBPreferences(darkenImages: 0.2, invertImages: 1.0, invertGaiji: 1.0))
            editor.invertGaiji.toggle()
            #expect(editor.preferences.invertGaiji == 0)

            let props = cssProperties(preferences: editor.preferences)
            #expect(props["--USER__darkenImages"] == "0.80000")
            #expect(props["--USER__invertImages"] == "1.00000")
            #expect(props["--USER__invertGaiji"] == .some(nil))
        }

        @Test("ReadiumCSS doesn't darken the images when stepped down to 0%")
        @MainActor func cssDarkenImagesSteppedDownToZero() throws {
            let editor = makeEditor(preferences: EPUBPreferences(darkenImages: 1.0))
            for _ in 0 ..< 10 {
                editor.darkenImages.decrement()
            }
            // Repeated decrements of 0.1 leave a residue instead of an exact 0.
            #expect(editor.darkenImages.format(value: try #require(editor.preferences.darkenImages)) == "0%")
            #expect(cssProperties(preferences: editor.preferences)["--USER__darkenImages"] == .some(nil))
        }

        @Test("the editor darkens the images by a percentage")
        @MainActor func editorDarkenImages() {
            let editor = makeEditor()
            #expect(editor.darkenImages.value == nil)
            #expect(editor.darkenImages.effectiveValue == 0)
            #expect(editor.darkenImages.supportedRange == 0.0 ... 1.0)
            #expect(editor.darkenImages.format(value: 0.5) == "50%")

            // Steps from 0% when unset.
            editor.darkenImages.decrement()
            #expect(editor.preferences.darkenImages == 0)
            editor.darkenImages.increment()
            #expect(editor.preferences.darkenImages == 0.1)

            editor.darkenImages.set(0.95)
            editor.darkenImages.increment()
            #expect(editor.preferences.darkenImages == 1.0)

            editor.darkenImages.clear()
            #expect(editor.preferences.darkenImages == nil)
            #expect(editor.darkenImages.effectiveValue == 0)
        }

        @Test("the editor toggles the inversions between 0% and 100%")
        @MainActor func editorInversionToggles() {
            let editor = makeEditor()
            for (filter, preference) in inversions(of: editor) {
                #expect(filter.value == nil)
                #expect(filter.effectiveValue == false)

                filter.toggle()
                #expect(editor.preferences[keyPath: preference] == 1.0)
                filter.toggle()
                #expect(editor.preferences[keyPath: preference] == 0.0)
                #expect(filter.effectiveValue == false)

                filter.clear()
                #expect(editor.preferences[keyPath: preference] == nil)
            }
        }

        @Test("the editor reads a partial inversion as on")
        @MainActor func editorPartialInversion() {
            let editor = makeEditor(preferences: EPUBPreferences(invertImages: 0.5, invertGaiji: 0.5))
            for (filter, _) in inversions(of: editor) {
                #expect(filter.value == true)
                #expect(filter.effectiveValue == true)
            }
        }

        /// The inversion toggles of the `editor`, with their preference.
        @MainActor private func inversions(
            of editor: EPUBPreferencesEditor
        ) -> [(filter: AnyPreference<Bool>, preference: KeyPath<EPUBPreferences, Double?>)] {
            [
                (editor.invertImages, \.invertImages),
                (editor.invertGaiji, \.invertGaiji),
            ]
        }
    }

    @Suite("colors") struct Colors {
        private let red = Color(rawValue: 0xFF0000)
        private let green = Color(rawValue: 0x00FF00)
        private let yellow = Color(rawValue: 0xFFFF00)

        @Test("the effective background color is white when unset")
        func effectiveBackgroundColor() {
            #expect(settings().effectiveBackgroundColor == Color(rawValue: 0xFFFFFF))
            #expect(settings(preferences: EPUBPreferences(backgroundColor: red)).effectiveBackgroundColor == red)
        }

        @Test("the editor uses the Readium CSS default colors when unset")
        @MainActor func editorDefaultEffectiveValues() {
            let editor = makeEditor()
            #expect(editor.textColor.value == nil)
            #expect(editor.textColor.effectiveValue == Color(rawValue: 0x121212))
            #expect(editor.backgroundColor.value == nil)
            #expect(editor.backgroundColor.effectiveValue == Color(rawValue: 0xFFFFFF))
            #expect(editor.linkColor.value == nil)
            #expect(editor.linkColor.effectiveValue == Color(rawValue: 0x0000EE))
            #expect(editor.visitedColor.value == nil)
            #expect(editor.visitedColor.effectiveValue == Color(rawValue: 0x551A8B))
        }

        @Test("the editor sets and clears the link colors")
        @MainActor func editorSetAndClear() {
            let editor = makeEditor()
            editor.linkColor.set(green)
            editor.visitedColor.set(yellow)
            #expect(editor.preferences.linkColor == green)
            #expect(editor.linkColor.effectiveValue == green)
            #expect(editor.linkColor.isEffective)
            #expect(editor.preferences.visitedColor == yellow)
            #expect(editor.visitedColor.effectiveValue == yellow)
            #expect(editor.visitedColor.isEffective)

            editor.linkColor.clear()
            editor.visitedColor.clear()
            #expect(editor.preferences.linkColor == nil)
            #expect(!editor.linkColor.isEffective)
            #expect(editor.preferences.visitedColor == nil)
            #expect(!editor.visitedColor.isEffective)
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

    @Suite("Codable") struct Coding {
        @Test("encodes and decodes every preference")
        func roundTrip() throws {
            let data = try JSONEncoder().encode(allPreferences)
            #expect(try JSONDecoder().decode(EPUBPreferences.self, from: data) == allPreferences)
        }

        @Test("merging keeps the preferences of the receiver which the other doesn't set")
        func merging() {
            #expect(EPUBPreferences().merging(allPreferences) == allPreferences)
            #expect(allPreferences.merging(EPUBPreferences()) == allPreferences)
        }

        @Test("merging takes the preferences set by the other")
        func mergingPrecedence() {
            #expect(allPreferences.merging(otherPreferences) == otherPreferences)
        }

        @Test("encodes the format version")
        func encodesVersion() throws {
            let data = try JSONEncoder().encode(EPUBPreferences(fontSize: 1.2))
            let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(json["version"] as? Int == 4)
            #expect(json["fontSize"] as? Double == 1.2)
            #expect(json.count == 2)
        }

        @Test("an invalid value drops only its preference", arguments: [#""version": 4"#, #""theme": "dark""#])
        func invalidValue(other: String) throws {
            let prefs = try decode(#"{"fontSize": "big", "lineHeight": 1.5, \#(other)}"#)
            #expect(prefs.fontSize == nil)
            #expect(prefs.lineHeight == 1.5)
        }

        @Test("decoded values are sanitized")
        func sanitized() throws {
            let prefs = try decode(#"{"version": 4, "columnCount": 0, "spread": "auto", "fontSize": -1}"#)
            #expect(prefs.columnCount == nil)
            #expect(prefs.spread == nil)
            #expect(prefs.fontSize == 0)
        }

        @Test("a versioned payload is not migrated")
        func versionedIsNotMigrated() throws {
            let prefs = try decode(#"{"version": 4, "theme": "dark", "imageFilter": "invert", "publisherStyles": true, "lineHeight": 1.5}"#)
            #expect(prefs == EPUBPreferences(lineHeight: 1.5))
        }

        @Test("migrates the 3.x dark theme to its colors")
        func legacyThemeDark() throws {
            let prefs = try decode(#"{"theme": "dark", "fontSize": 1.2}"#)
            #expect(prefs == EPUBPreferences(
                backgroundColor: Color(rawValue: 0x000000),
                fontSize: 1.2,
                invertGaiji: 1.0,
                linkColor: Color(rawValue: 0x63CAFF),
                textColor: Color(rawValue: 0xFEFEFE),
                visitedColor: Color(rawValue: 0x0099E5)
            ))
        }

        @Test("migrates the 3.x sepia theme to its colors, without link colors")
        func legacyThemeSepia() throws {
            let prefs = try decode(#"{"theme": "sepia", "fontSize": 1.2}"#)
            #expect(prefs == EPUBPreferences(
                backgroundColor: Color(rawValue: 0xFAF4E8),
                fontSize: 1.2,
                textColor: Color(rawValue: 0x121212)
            ))
        }

        @Test("migrates the 3.x light theme, or an invalid one, to no colors", arguments: [#""theme": "light","#, #""theme": "unknown","#, #""theme": 2,"#, ""])
        func legacyThemeLight(theme: String) throws {
            let prefs = try decode(#"{\#(theme) "fontSize": 1.2}"#)
            #expect(prefs == EPUBPreferences(fontSize: 1.2))
        }

        @Test("the colors saved with a 3.x theme take precedence over its colors")
        func legacyThemeWithExplicitColors() throws {
            // Colors are serialized as packed integers.
            let dark = try decode(#"{"theme": "dark", "textColor": 16711680}"#)
            #expect(dark == EPUBPreferences(
                backgroundColor: Color(rawValue: 0x000000),
                invertGaiji: 1.0,
                linkColor: Color(rawValue: 0x63CAFF),
                textColor: Color(rawValue: 0xFF0000),
                visitedColor: Color(rawValue: 0x0099E5)
            ))

            let sepia = try decode(#"{"theme": "sepia", "backgroundColor": 65280}"#)
            #expect(sepia == EPUBPreferences(
                backgroundColor: Color(rawValue: 0x00FF00),
                textColor: Color(rawValue: 0x121212)
            ))

            let light = try decode(#"{"theme": "light", "textColor": 16711680, "backgroundColor": 65280}"#)
            #expect(light == EPUBPreferences(
                backgroundColor: Color(rawValue: 0x00FF00),
                textColor: Color(rawValue: 0xFF0000)
            ))
        }

        @Test("migrates the 3.x column count", arguments: [
            ("auto", nil),
            ("1", 1),
            ("2", 2),
        ] as [(String, Int?)])
        func legacyColumnCount(value: String, expected: Int?) throws {
            let prefs = try decode(#"{"columnCount": "\#(value)", "fontSize": 1.2}"#)
            #expect(prefs.columnCount == expected)
            #expect(prefs.fontSize == 1.2)
        }

        /// The dark theme inverted the gaiji, unless the images were
        /// darkened.
        @Test("migrates the 3.x image filters with the dark theme", arguments: [
            (#""imageFilter": "darken""#, 0.2, nil, nil),
            (#""imageFilter": "invert""#, nil, 1.0, 1.0),
            (#""imageFilter": "unknown""#, nil, nil, 1.0),
            (#""fontSize": 1.2"#, nil, nil, 1.0),
        ] as [(String, Double?, Double?, Double?)])
        func legacyImageFilterDark(filter: String, darkenImages: Double?, invertImages: Double?, invertGaiji: Double?) throws {
            let prefs = try decode(#"{"theme": "dark", \#(filter)}"#)
            #expect(prefs.darkenImages == darkenImages)
            #expect(prefs.invertImages == invertImages)
            #expect(prefs.invertGaiji == invertGaiji)
        }

        @Test("drops the 3.x image filters without the dark theme", arguments: [#""theme": "light","#, #""theme": "sepia","#, ""])
        func legacyImageFilterNotDark(theme: String) throws {
            for filter in ["darken", "invert"] {
                let prefs = try decode(#"{\#(theme) "imageFilter": "\#(filter)"}"#)
                #expect(prefs.darkenImages == nil)
                #expect(prefs.invertImages == nil)
                #expect(prefs.invertGaiji == nil)
            }
        }

        @Test("drops the preferences ignored with the 3.x publisher styles")
        func legacyPublisherStylesOn() throws {
            let prefs = try decode(threeXPayload(publisherStyles: true))
            #expect(prefs == EPUBPreferences(
                backgroundColor: Color(rawValue: 0x000000),
                columnCount: 2,
                fontSize: 1.2,
                invertGaiji: 1.0,
                linkColor: Color(rawValue: 0x63CAFF),
                textColor: Color(rawValue: 0xFEFEFE),
                visitedColor: Color(rawValue: 0x0099E5)
            ))
        }

        @Test("keeps the preferences when the 3.x publisher styles are off or unset", arguments: [false, nil])
        func legacyPublisherStylesOffOrUnset(publisherStyles: Bool?) throws {
            let prefs = try decode(threeXPayload(publisherStyles: publisherStyles))
            #expect(prefs == EPUBPreferences(
                backgroundColor: Color(rawValue: 0x000000),
                columnCount: 2,
                fontSize: 1.2,
                hyphens: true,
                invertGaiji: 1.0,
                letterSpacing: 0.1,
                ligatures: false,
                lineHeight: 2.0,
                linkColor: Color(rawValue: 0x63CAFF),
                paragraphIndent: 1.0,
                paragraphSpacing: 0.5,
                textAlign: .justify,
                textColor: Color(rawValue: 0xFEFEFE),
                visitedColor: Color(rawValue: 0x0099E5),
                wordSpacing: 0.2
            ))
        }

        /// A payload serialized by the 3.x toolkit, with the preferences
        /// ignored while the publisher styles were enabled.
        private func threeXPayload(publisherStyles: Bool?) -> String {
            let publisherStyles = publisherStyles.map { #""publisherStyles": \#($0),"# } ?? ""
            return #"""
            {
                \#(publisherStyles)
                "columnCount": "2",
                "fontSize": 1.2,
                "hyphens": true,
                "letterSpacing": 0.1,
                "ligatures": false,
                "lineHeight": 2.0,
                "paragraphIndent": 1.0,
                "paragraphSpacing": 0.5,
                "textAlign": "justify",
                "theme": "dark",
                "typeScale": 1.2,
                "wordSpacing": 0.2
            }
            """#
        }

        private func decode(_ json: String) throws -> EPUBPreferences {
            try JSONDecoder().decode(EPUBPreferences.self, from: Data(json.utf8))
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
                invertGaiji: 1.0,
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
                invertGaiji: 1.0,
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

/// Every preference set to a distinct non-default value.
private let allPreferences = EPUBPreferences(
    backgroundColor: Color(hex: "#FF0000"),
    columnCount: 2,
    fit: .width,
    fontFamily: "Literata",
    fontSize: 1.4,
    fontWeight: 1.75,
    fontWidth: 1.7,
    hyphens: true,
    blendImages: true,
    darkenImages: 0.3,
    invertImages: 0.4,
    invertGaiji: 0.6,
    language: Language(code: .bcp47("fr")),
    letterSpacing: 0.1,
    ligatures: false,
    lineHeight: 1.6,
    linkColor: Color(hex: "#0000FF"),
    maximalLineLength: 1.3,
    minimalLineLength: 0.8,
    noRuby: true,
    offsetFirstPage: true,
    optimalLineLength: 1.2,
    pageMargins: 1.5,
    paragraphIndent: 1.1,
    paragraphSpacing: 0.5,
    readingProgression: .rtl,
    scroll: true,
    spread: .always,
    textAlign: .justify,
    textColor: Color(hex: "#00FF00"),
    textNormalization: true,
    verticalText: true,
    visitedColor: Color(hex: "#FF00FF"),
    wordSpacing: 0.2
)

/// Every preference set to a value different from the ones of
/// `allPreferences` and `allDefaults`.
private let otherPreferences = EPUBPreferences(
    backgroundColor: Color(hex: "#00FFFF"),
    columnCount: 1,
    fit: .auto,
    fontFamily: "Iowan Old Style",
    fontSize: 0.9,
    fontWeight: 0.5,
    fontWidth: 0.8,
    hyphens: false,
    blendImages: false,
    darkenImages: 0.7,
    invertImages: 0.9,
    invertGaiji: 0.2,
    language: Language(code: .bcp47("de")),
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
    language: Language(code: .bcp47("it")),
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

/// The preferences which are effective in the editor only when they are set.
private let setOnlyPreferences = EPUBPreferences(
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
    (EPUBPreferences(invertImages: 1.0), ["--USER__invertImages": "1.00000"]),
    (EPUBPreferences(invertGaiji: 1.0), ["--USER__invertGaiji": "1.00000"]),
    (EPUBPreferences(language: Language(code: .bcp47("fr"))), [:]),
    // ReadiumCSS halves the letter spacing.
    (EPUBPreferences(letterSpacing: 0.2), ["--USER__letterSpacing": "0.10000rem"]),
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
    defaults: EPUBDefaults = EPUBDefaults()
) -> EPUBSettings {
    EPUBSettings(
        preferences: preferences,
        defaults: defaults,
        metadata: Metadata(title: "Test")
    )
}

/// Readium CSS properties emitted for the given `settings`, before the layout
/// is resolved.
@MainActor private func cssProperties(_ settings: EPUBSettings) -> [String: String?] {
    var css = ReadiumCSS(baseURL: HTTPURL(string: "https://readium/")!)
    css.update(with: settings)
    return css.rsProperties.cssProperties()
        .merging(css.userProperties.cssProperties()) { _, user in user }
}

@MainActor private func cssProperties(
    preferences: EPUBPreferences = EPUBPreferences(),
    defaults: EPUBDefaults = EPUBDefaults()
) -> [String: String?] {
    cssProperties(settings(preferences: preferences, defaults: defaults))
}

@MainActor private func makeEditor(
    preferences: EPUBPreferences = EPUBPreferences(),
    defaults: EPUBDefaults = EPUBDefaults(),
    layout: Layout? = nil,
    readingOrder: [Link] = [Link(href: "c1.xhtml", mediaType: .xhtml)]
) -> EPUBPreferencesEditor {
    EPUBPreferencesEditor(
        initialPreferences: preferences,
        publication: Publication(
            manifest: Manifest(
                metadata: Metadata(title: "Test", layout: layout),
                readingOrder: readingOrder
            )
        ),
        defaults: defaults
    )
}

/// Names of the preferences which are effective in the `editor`.
@MainActor private func effectivePreferences(of editor: EPUBPreferencesEditor) -> Set<String> {
    Set(editorPreferences(of: editor).filter(\.isEffective).map(\.name))
}

/// Every preference of the `editor`, with whether it is effective.
@MainActor private func editorPreferences(of editor: EPUBPreferencesEditor) -> [(name: String, isEffective: Bool)] {
    [
        ("backgroundColor", editor.backgroundColor.isEffective),
        ("blendImages", editor.blendImages.isEffective),
        ("columnCount", editor.columnCount.isEffective),
        ("darkenImages", editor.darkenImages.isEffective),
        ("fit", editor.fit.isEffective),
        ("fontFamily", editor.fontFamily.isEffective),
        ("fontSize", editor.fontSize.isEffective),
        ("fontWeight", editor.fontWeight.isEffective),
        ("fontWidth", editor.fontWidth.isEffective),
        ("hyphens", editor.hyphens.isEffective),
        ("invertGaiji", editor.invertGaiji.isEffective),
        ("invertImages", editor.invertImages.isEffective),
        ("language", editor.language.isEffective),
        ("letterSpacing", editor.letterSpacing.isEffective),
        ("ligatures", editor.ligatures.isEffective),
        ("lineHeight", editor.lineHeight.isEffective),
        ("linkColor", editor.linkColor.isEffective),
        ("maximalLineLength", editor.maximalLineLength.isEffective),
        ("minimalLineLength", editor.minimalLineLength.isEffective),
        ("noRuby", editor.noRuby.isEffective),
        ("offsetFirstPage", editor.offsetFirstPage.isEffective),
        ("optimalLineLength", editor.optimalLineLength.isEffective),
        ("pageMargins", editor.pageMargins.isEffective),
        ("paragraphIndent", editor.paragraphIndent.isEffective),
        ("paragraphSpacing", editor.paragraphSpacing.isEffective),
        ("readingProgression", editor.readingProgression.isEffective),
        ("scroll", editor.scroll.isEffective),
        ("spread", editor.spread.isEffective),
        ("textAlign", editor.textAlign.isEffective),
        ("textColor", editor.textColor.isEffective),
        ("textNormalization", editor.textNormalization.isEffective),
        ("verticalText", editor.verticalText.isEffective),
        ("visitedColor", editor.visitedColor.isEffective),
        ("wordSpacing", editor.wordSpacing.isEffective),
    ]
}
