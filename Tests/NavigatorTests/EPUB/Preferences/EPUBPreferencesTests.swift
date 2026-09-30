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

        @Test("ReadiumCSS doesn't emit a column count when auto and unresolved")
        @MainActor func cssAuto() throws {
            var css = try ReadiumCSS(baseURL: #require(HTTPURL(string: "https://readium/")))
            css.update(with: settings())
            #expect(css.userProperties.cssProperties()["--USER__colCount"] == .some(nil))
        }

        @Test("ReadiumCSS emits the column count when unresolved")
        @MainActor func cssColumnCount() throws {
            var css = try ReadiumCSS(baseURL: #require(HTTPURL(string: "https://readium/")))
            css.update(with: settings(preferences: EPUBPreferences(columnCount: 2)))
            #expect(css.userProperties.cssProperties()["--USER__colCount"] == "2")
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
