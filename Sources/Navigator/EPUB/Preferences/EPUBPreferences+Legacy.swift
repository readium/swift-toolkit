//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

public extension EPUBPreferences {
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
                .flatMap { (columnCountValues ?? UserSettings.columnCountValues).getOrNil($0) }
                .flatMap { ColumnCount(rawValue: $0) },
            fontFamily: defaults.optInt(for: .fontFamily)
                .takeIf { $0 != 0 } // Original
                .flatMap { (fontFamilyValues ?? UserSettings.fontFamilyValues).getOrNil($0) }
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
                .flatMap { (columnCountValues ?? UserSettings.columnCountValues).getOrNil($0) }
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
                .flatMap { (textAlignmentValues ?? UserSettings.textAlignmentValues).getOrNil($0) }
                .flatMap { TextAlignment(rawValue: $0) },
            textColor: defaults.optString(for: .textColor)
                .flatMap { Color(hex: $0) },
            theme: defaults.optInt(for: .appearance)
                .flatMap { (appearanceValues ?? UserSettings.appearanceValues).getOrNil($0) }
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
