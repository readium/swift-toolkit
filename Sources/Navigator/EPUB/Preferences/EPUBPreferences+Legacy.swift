//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public extension EPUBPreferences {
    // WARNING: String values must not contain any single or double quotes characters, otherwise it breaks the streamer's injection.
    private static let defaultAppearanceValues = ["readium-default-on", "readium-sepia-on", "readium-night-on"]
    private static let defaultFontFamilyValues = ["Original", "Helvetica Neue", "Iowan Old Style", "Athelas", "Seravek", "OpenDyslexic", "AccessibleDfA", "IA Writer Duospace"]
    private static let defaultTextAlignmentValues = ["justify", "start"]
    private static let defaultColumnCountValues = ["auto", "1", "2"]

    /// Loads the preferences from the legacy EPUB settings stored in the
    /// standard `UserDefaults`.
    ///
    /// This can be used to migrate the legacy settings to the new
    /// `EPUBPreferences` format.
    ///
    /// Provide some of the values overrides if you modified the default ones
    /// in the Readium toolkit.
    static func fromLegacyPreferences(
        appearanceValues: [String]? = nil,
        columnCountValues: [String]? = nil,
        fontFamilyValues: [String]? = nil,
        textAlignmentValues: [String]? = nil
    ) -> EPUBPreferences {
        let defaults = UserDefaults.standard

        return EPUBPreferences(
            backgroundColor: defaults.optString(for: .backgroundColor)
                .flatMap { Color(hex: $0) },
            columnCount: defaults.optInt(for: .columnCount)
                .flatMap { (columnCountValues ?? defaultColumnCountValues).getOrNil($0) }
                .flatMap { ColumnCount(rawValue: $0) },
            fontFamily: defaults.optInt(for: .fontFamily)
                .takeIf { $0 != 0 } // Original
                .flatMap { (fontFamilyValues ?? defaultFontFamilyValues).getOrNil($0) }
                .map { FontFamily(rawValue: $0) },
            fontSize: defaults.optDouble(for: .fontSize)
                .map { $0 / 100 },
            hyphens: defaults.optBool(for: .hyphens),
            letterSpacing: defaults.optDouble(for: .letterSpacing),
            lineHeight: defaults.optDouble(for: .lineHeight),
            pageMargins: defaults.optDouble(for: .pageMargins),
            paragraphSpacing: defaults.optDouble(for: .paragraphMargins),
            publisherStyles: defaults.optBool(for: .publisherDefault),
            scroll: defaults.optBool(for: .scroll),
            // Used to be merged with column-count
            spread: defaults.optInt(for: .columnCount)
                .flatMap { (columnCountValues ?? defaultColumnCountValues).getOrNil($0) }
                .flatMap {
                    switch $0 {
                    case "auto":
                        return .auto
                    case "1":
                        return .never
                    case "2":
                        return .always
                    default:
                        return nil
                    }
                },
            textAlign: defaults.optInt(for: .textAlignment)
                .flatMap { (textAlignmentValues ?? defaultTextAlignmentValues).getOrNil($0) }
                .flatMap { TextAlignment(rawValue: $0) },
            textColor: defaults.optString(for: .textColor)
                .flatMap { Color(hex: $0) },
            theme: defaults.optInt(for: .appearance)
                .flatMap { (appearanceValues ?? defaultAppearanceValues).getOrNil($0) }
                .flatMap {
                    switch $0 {
                    case "readium-default-on":
                        return .light
                    case "readium-night-on":
                        return .dark
                    case "readium-sepia-on":
                        return .sepia
                    default:
                        return nil
                    }
                },
            wordSpacing: defaults.optDouble(for: .wordSpacing)
        )
    }
}

private extension UserDefaults {
    func contains(_ key: ReadiumCSSName) -> Bool {
        object(forKey: key.rawValue) != nil
    }

    func optBool(for key: ReadiumCSSName) -> Bool? {
        guard contains(key) else {
            return nil
        }
        return bool(forKey: key.rawValue)
    }

    func optDouble(for key: ReadiumCSSName) -> Double? {
        guard contains(key) else {
            return nil
        }
        return double(forKey: key.rawValue)
    }

    func optInt(for key: ReadiumCSSName) -> Int? {
        guard contains(key) else {
            return nil
        }
        return integer(forKey: key.rawValue)
    }

    func optString(for key: ReadiumCSSName) -> String? {
        guard contains(key) else {
            return nil
        }
        return string(forKey: key.rawValue)
    }
}

/// List of strings that can identify the name of a CSS custom property
private enum ReadiumCSSName: String {
    case fontSize = "--USER__fontSize"
    case fontFamily = "--USER__fontFamily"
    case fontOverride = "--USER__fontOverride"
    case appearance = "--USER__appearance"
    case scroll = "--USER__scroll"
    case publisherDefault = "--USER__advancedSettings"
    case textAlignment = "--USER__textAlign"
    case columnCount = "--USER__colCount"
    case wordSpacing = "--USER__wordSpacing"
    case letterSpacing = "--USER__letterSpacing"
    case pageMargins = "--USER__pageMargins"
    case lineHeight = "--USER__lineHeight"
    case paraIndent = "--USER__paraIndent"
    case hyphens = "--USER__bodyHyphens"
    case ligatures = "--USER__ligatures"
    case paragraphMargins = "--USER__paraSpacing"
    case textColor = "--USER__textColor"
    case backgroundColor = "--USER__backgroundColor"
}
