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

        @Test("the setting is nil (auto) when unset")
        func settingDefaultsToAuto() {
            #expect(settings().columnCount == nil)
        }

        @Test("the setting falls back on the defaults")
        func settingFallsBackOnDefaults() {
            #expect(settings(defaults: EPUBDefaults(columnCount: 2)).columnCount == 2)
        }

        @Test("the preference takes precedence over the defaults")
        func preferenceTakesPrecedence() {
            #expect(
                settings(
                    preferences: EPUBPreferences(columnCount: 1),
                    defaults: EPUBDefaults(columnCount: 2)
                ).columnCount == 1
            )
        }

        @Test("ReadiumCSS doesn't emit a column count before the layout is resolved", arguments: [nil, 2])
        @MainActor func cssColumnCountUnresolved(columnCount: Int?) throws {
            var css = try ReadiumCSS(baseURL: #require(HTTPURL(string: "https://readium/")))
            css.update(with: settings(preferences: EPUBPreferences(columnCount: columnCount)))
            #expect(css.userProperties.cssProperties()["--USER__colCount"] == .some(nil))
        }

        @Test("the editor supports auto, 1 and 2 columns")
        @MainActor func editorSupportedValues() {
            let editor = makeEditor()
            #expect(editor.columnCount.supportedValues == [nil, 1, 2])
            #expect(editor.preferences.columnCount == nil)
            #expect(editor.columnCount.effectiveValue == nil)
            #expect(editor.columnCount.isEffective)
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

        @Test("the editor uses the defaults as effective value")
        @MainActor func editorEffectiveValueFromDefaults() {
            let editor = makeEditor(defaults: EPUBDefaults(columnCount: 1))
            #expect(editor.preferences.columnCount == nil)
            #expect(editor.columnCount.effectiveValue == 1)
        }

        @Test("the editor preference is not effective in scroll mode")
        @MainActor func editorNotEffectiveWhenScrolling() {
            let editor = makeEditor(preferences: EPUBPreferences(scroll: true))
            #expect(!editor.columnCount.isEffective)
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

        @Test("the settings have an optimal line length and no limits when unset")
        func settingsWhenUnset() {
            let settings = settings()
            #expect(settings.optimalLineLength == 1.0)
            #expect(settings.minimalLineLength == nil)
            #expect(settings.maximalLineLength == nil)
        }

        @Test("the settings fall back on the defaults")
        func settingsFallBackOnDefaults() {
            let settings = settings(defaults: EPUBDefaults(
                maximalLineLength: 1.2,
                minimalLineLength: 0.8,
                optimalLineLength: 0.9
            ))
            #expect(settings.optimalLineLength == 0.9)
            #expect(settings.minimalLineLength == 0.8)
            #expect(settings.maximalLineLength == 1.2)
        }

        @Test("the preferences take precedence over the defaults")
        func preferencesTakePrecedence() {
            let settings = settings(
                preferences: EPUBPreferences(
                    maximalLineLength: 1.5,
                    minimalLineLength: 0.6,
                    optimalLineLength: 1.1
                ),
                defaults: EPUBDefaults(
                    maximalLineLength: 1.2,
                    minimalLineLength: 0.8,
                    optimalLineLength: 0.9
                )
            )
            #expect(settings.optimalLineLength == 1.1)
            #expect(settings.minimalLineLength == 0.6)
            #expect(settings.maximalLineLength == 1.5)
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
        @Test("the setting is nil when unset, to observe the publisher styles")
        func settingIsNilWhenUnset() {
            #expect(settings().lineHeight == nil)
        }

        @Test("the editor uses the Readium CSS base line height when unset")
        @MainActor func editorDefaultEffectiveValue() {
            let editor = makeEditor()
            #expect(editor.lineHeight.value == nil)
            #expect(editor.lineHeight.effectiveValue == 1.5)
            #expect(!editor.lineHeight.isEffective)
        }

        @Test("the editor increments from the Readium CSS base line height when unset")
        @MainActor func editorIncrementsFromDefault() {
            let editor = makeEditor()
            editor.lineHeight.increment()
            #expect(editor.preferences.lineHeight == 1.6)
            #expect(editor.lineHeight.effectiveValue == 1.6)
            #expect(editor.lineHeight.isEffective)
        }

        @Test("the editor decrements from the Readium CSS base line height when unset")
        @MainActor func editorDecrementsFromDefault() {
            let editor = makeEditor()
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

    @Suite("ligatures") struct Ligatures {
        @Test("the editor preference is effective with LTR and RTL languages", arguments: [
            ("en", CSSLayout.Stylesheets.default),
            ("ar", CSSLayout.Stylesheets.rtl),
        ])
        @MainActor func editorEffective(language: String, stylesheets: CSSLayout.Stylesheets) {
            let preferences = EPUBPreferences(
                language: Language(code: .bcp47(language)),
                ligatures: true
            )
            #expect(settings(preferences: preferences).cssLayout.stylesheets == stylesheets)

            let editor = makeEditor(preferences: preferences)
            #expect(editor.ligatures.isEffective)
        }

        @Test("the editor preference is not effective with CJK languages", arguments: [
            (false, CSSLayout.Stylesheets.cjkHorizontal),
            (true, CSSLayout.Stylesheets.cjkVertical),
        ])
        @MainActor func editorNotEffectiveWithCJK(verticalText: Bool, stylesheets: CSSLayout.Stylesheets) {
            let preferences = EPUBPreferences(
                language: Language(code: .bcp47("ja")),
                ligatures: true,
                verticalText: verticalText
            )
            #expect(settings(preferences: preferences).cssLayout.stylesheets == stylesheets)

            let editor = makeEditor(preferences: preferences)
            #expect(!editor.ligatures.isEffective)
        }

        @Test("the editor preference is not effective when unset")
        @MainActor func editorNotEffectiveWhenUnset() {
            let editor = makeEditor()
            #expect(!editor.ligatures.isEffective)
        }

        @Test("the editor preference is not effective without reflowable resources")
        @MainActor func editorNotEffectiveWithFixedLayout() {
            let editor = EPUBPreferencesEditor(
                initialPreferences: EPUBPreferences(ligatures: true),
                publication: Publication(
                    manifest: Manifest(
                        metadata: Metadata(title: "Test", layout: .fixed),
                        readingOrder: [Link(href: "c1.xhtml", mediaType: .xhtml)]
                    )
                ),
                defaults: EPUBDefaults()
            )
            #expect(!editor.ligatures.isEffective)
        }
    }

    @Suite("image filters") struct ImageFilters {
        @Test("ReadiumCSS applies the image filters with any theme", arguments: [Theme.light, .dark, .sepia])
        @MainActor func cssImageFilters(theme: Theme) throws {
            var css = try ReadiumCSS(baseURL: #require(HTTPURL(string: "https://readium/")))
            css.update(with: settings(preferences: EPUBPreferences(
                darkenImages: 0.2,
                invertImages: 1.0,
                invertGaiji: 1.0,
                theme: theme
            )))

            let props = css.userProperties.cssProperties()
            #expect(props["--USER__darkenImages"] == "0.80000")
            #expect(props["--USER__invertImages"] == "1.00000")
            #expect(props["--USER__invertGaiji"] == "1.00000")
        }

        @Test("ReadiumCSS doesn't apply the image filters when unset", arguments: [Theme.light, .dark, .sepia])
        @MainActor func cssImageFiltersUnset(theme: Theme) throws {
            var css = try ReadiumCSS(baseURL: #require(HTTPURL(string: "https://readium/")))
            css.update(with: settings(preferences: EPUBPreferences(theme: theme)))

            let props = css.userProperties.cssProperties()
            #expect(props["--USER__darkenImages"] == .some(nil))
            #expect(props["--USER__invertImages"] == .some(nil))
            #expect(props["--USER__invertGaiji"] == .some(nil))
        }

        @Test("the editor preferences are effective with any theme", arguments: [Theme.light, .dark, .sepia])
        @MainActor func editorEffective(theme: Theme) {
            let editor = makeEditor(preferences: EPUBPreferences(theme: theme))
            #expect(editor.darkenImages.isEffective)
            #expect(editor.invertImages.isEffective)
            #expect(editor.invertGaiji.isEffective)
        }
    }

    @Suite("Codable") struct Coding {
        /// Every preference set to a non-default value.
        private let allPreferences = EPUBPreferences(
            backgroundColor: Color(hex: "#FF0000"),
            columnCount: 2,
            fit: .width,
            fontFamily: "Literata",
            fontSize: 1.4,
            fontWeight: 1.5,
            hyphens: true,
            blendImages: true,
            darkenImages: 0.3,
            invertImages: 0.4,
            invertGaiji: 0.5,
            language: Language(code: .bcp47("fr")),
            letterSpacing: 0.1,
            ligatures: false,
            lineHeight: 1.6,
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
            theme: .sepia,
            verticalText: true,
            wordSpacing: 0.2
        )

        /// Keeps the round-trip test exhaustive.
        ///
        /// A stored property missing from the `Codable` implementation would
        /// still pass the round-trip test if the fixture left it `nil`. This
        /// test lists the stored properties with a `Mirror`, so it fails as
        /// soon as a new property is added to `EPUBPreferences` without being
        /// set in the fixture.
        @Test("the round-trip fixture sets every preference")
        func fixtureIsComplete() {
            for child in Mirror(reflecting: allPreferences).children {
                let value = Mirror(reflecting: child.value)
                let isNil = value.displayStyle == .optional && value.children.isEmpty
                #expect(!isNil, "\(child.label ?? "?") is not set in the fixture")
            }
        }

        @Test("encodes and decodes every preference")
        func roundTrip() throws {
            let data = try JSONEncoder().encode(allPreferences)
            #expect(try JSONDecoder().decode(EPUBPreferences.self, from: data) == allPreferences)
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
            #expect(prefs.invertImages == nil)
            #expect(prefs.lineHeight == 1.5)
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

        @Test("migrates the 3.x image filters with the dark theme")
        func legacyImageFilterDark() throws {
            let darken = try decode(#"{"theme": "dark", "imageFilter": "darken"}"#)
            #expect(darken.darkenImages == 0.2)
            #expect(darken.invertImages == nil)

            let invert = try decode(#"{"theme": "dark", "imageFilter": "invert"}"#)
            #expect(invert.darkenImages == nil)
            #expect(invert.invertImages == 1.0)
        }

        @Test("drops the 3.x image filters without the dark theme", arguments: [#""theme": "light","#, #""theme": "sepia","#, ""])
        func legacyImageFilterNotDark(theme: String) throws {
            for filter in ["darken", "invert"] {
                let prefs = try decode(#"{\#(theme) "imageFilter": "\#(filter)"}"#)
                #expect(prefs.darkenImages == nil)
                #expect(prefs.invertImages == nil)
            }
        }

        @Test("drops the preferences ignored with the 3.x publisher styles")
        func legacyPublisherStylesOn() throws {
            let prefs = try decode(threeXPayload(publisherStyles: true))
            #expect(prefs == EPUBPreferences(
                columnCount: 2,
                fontSize: 1.2,
                theme: .dark
            ))
        }

        @Test("keeps the preferences when the 3.x publisher styles are off or unset", arguments: [false, nil])
        func legacyPublisherStylesOffOrUnset(publisherStyles: Bool?) throws {
            let prefs = try decode(threeXPayload(publisherStyles: publisherStyles))
            #expect(prefs == EPUBPreferences(
                columnCount: 2,
                fontSize: 1.2,
                hyphens: true,
                letterSpacing: 0.1,
                ligatures: false,
                lineHeight: 2.0,
                paragraphIndent: 1.0,
                paragraphSpacing: 0.5,
                textAlign: .justify,
                theme: .dark,
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

        @Test("migrates the auto column count to nil")
        func columnCountAuto() {
            let prefs = withLegacyColumnCount(0) {
                EPUBPreferences.fromLegacyPreferences()
            }
            #expect(prefs.columnCount == nil)
            #expect(prefs.spread == nil) // .auto is not a valid spread preference
        }

        @Test("migrates a column count of 1")
        func columnCountOne() {
            let prefs = withLegacyColumnCount(1) {
                EPUBPreferences.fromLegacyPreferences()
            }
            #expect(prefs.columnCount == 1)
            #expect(prefs.spread == .never)
        }

        @Test("migrates a column count of 2")
        func columnCountTwo() {
            let prefs = withLegacyColumnCount(2) {
                EPUBPreferences.fromLegacyPreferences()
            }
            #expect(prefs.columnCount == 2)
            #expect(prefs.spread == .always)
        }

        private func withLegacyColumnCount<T>(_ index: Int, _ block: () -> T) -> T {
            let defaults = UserDefaults.standard
            defaults.set(index, forKey: columnCountKey)
            defer { defaults.removeObject(forKey: columnCountKey) }
            return block()
        }
    }
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

@MainActor private func makeEditor(
    preferences: EPUBPreferences = EPUBPreferences(),
    defaults: EPUBDefaults = EPUBDefaults()
) -> EPUBPreferencesEditor {
    EPUBPreferencesEditor(
        initialPreferences: preferences,
        publication: Publication(
            manifest: Manifest(
                metadata: Metadata(title: "Test"),
                readingOrder: [Link(href: "c1.xhtml", mediaType: .xhtml)]
            )
        ),
        defaults: defaults
    )
}
