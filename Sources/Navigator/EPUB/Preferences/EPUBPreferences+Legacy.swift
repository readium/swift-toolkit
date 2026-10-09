//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

// MARK: - Legacy settings stored in the UserDefaults (2.x)

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

        var preferences = EPUBPreferences(
            backgroundColor: defaults.optString(for: .backgroundColor)
                .flatMap { Color(hex: $0) },
            columnCount: defaults.optInt(for: .columnCount)
                .flatMap { (columnCountValues ?? defaultColumnCountValues).getOrNil($0) }
                .flatMap { Int($0) },
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
            wordSpacing: defaults.optDouble(for: .wordSpacing)
        )

        // The appearance is migrated to the color preferences (and the gaiji
        // inversion of the night mode), as Readium CSS v2 has no themes. The
        // legacy colors take precedence.
        let theme: LegacyTheme? = defaults.optInt(for: .appearance)
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
            }
        if let theme = theme {
            preferences.applyLegacyTheme(theme)
        }

        return preferences
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

// MARK: - Preferences serialized without a version (3.x)

extension EPUBPreferences {
    /// Keys of the preferences serialized without a version, which changed
    /// or were removed.
    private enum LegacyCodingKeys: String, CodingKey {
        case columnCount
        case imageFilter
        case publisherStyles
        case theme
    }

    /// Migrates the preferences serialized without a version, before the
    /// Readium CSS v2 upgrade.
    ///
    /// The `typeScale` preference is dropped.
    mutating func migrateUnversioned(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: LegacyCodingKeys.self)

        // `columnCount` was an enum of `auto`, `1` and `2`.
        if let columnCount = container.decodeLeniently(String.self, forKey: .columnCount) {
            self.columnCount = Int(columnCount).takeIf { $0 >= 1 }
        }

        // `theme` was an enum of `light`, `dark` and `sepia`, and
        // `imageFilter` an enum of `darken` and `invert`.
        let theme = container.decodeLeniently(String.self, forKey: .theme)
            .flatMap(LegacyTheme.init(rawValue:))
        if let theme = theme {
            applyLegacyTheme(
                theme,
                imageFilter: container.decodeLeniently(String.self, forKey: .imageFilter)
            )
        }

        // These preferences were ignored while the publisher styles were
        // enabled. An unset `publisherStyles` is ambiguous, as apps could
        // change its default value, so they are kept in this case.
        if container.decodeLeniently(Bool.self, forKey: .publisherStyles) == true {
            hyphens = nil
            letterSpacing = nil
            ligatures = nil
            lineHeight = nil
            paragraphIndent = nil
            paragraphSpacing = nil
            textAlign = nil
            wordSpacing = nil
        }
    }
}

// MARK: - Legacy themes

/// Themes of the toolkit before the Readium CSS v2 upgrade, which has no
/// themes anymore. They are migrated to the color preferences.
enum LegacyTheme: String {
    case light
    case dark
    case sepia
}

// Colors of the night and sepia modes of Readium CSS v1.
private let nightTextColor = Color(rawValue: 0xFEFEFE)
private let nightBackgroundColor = Color(rawValue: 0x000000)
private let nightLinkColor = Color(rawValue: 0x63CAFF)
private let nightVisitedColor = Color(rawValue: 0x0099E5)
private let sepiaTextColor = Color(rawValue: 0x121212)
private let sepiaBackgroundColor = Color(rawValue: 0xFAF4E8)

extension EPUBPreferences {
    /// Migrates the legacy `theme` to the preferences giving the rendering it
    /// had with Readium CSS v1.
    ///
    /// The colors already set are kept, as they took precedence over the
    /// theme. The light theme has no colors, it was the default rendering.
    ///
    /// - Parameter imageFilter: Legacy image filter (`darken` or `invert`),
    ///   which was applied only with the dark theme.
    mutating func applyLegacyTheme(_ theme: LegacyTheme, imageFilter: String? = nil) {
        switch theme {
        case .light:
            break

        case .dark:
            textColor = textColor ?? nightTextColor
            backgroundColor = backgroundColor ?? nightBackgroundColor
            linkColor = linkColor ?? nightLinkColor
            visitedColor = visitedColor ?? nightVisitedColor

            // The dark theme inverted the gaiji, unless the images were
            // darkened.
            switch imageFilter {
            case "darken":
                // The `darken` filter was `brightness(80%)`.
                darkenImages = 0.2
            case "invert":
                invertImages = 1.0
                invertGaiji = 1.0
            default:
                invertGaiji = 1.0
            }

        case .sepia:
            // The link colors of the sepia theme were the default ones.
            textColor = textColor ?? sepiaTextColor
            backgroundColor = backgroundColor ?? sepiaBackgroundColor
        }
    }
}

// MARK: - Removed preferences

public extension EPUBPreferences {
    @available(*, unavailable, message: "Not needed anymore with Readium CSS v2, user settings are applied as soon as they are set")
    var publisherStyles: Bool? {
        fatalError()
    }

    @available(*, unavailable, message: "Not available in Readium CSS v2")
    var typeScale: Double? {
        fatalError()
    }

    @available(*, unavailable, message: "Use darkenImages or invertImages instead")
    var imageFilter: ImageFilter? {
        fatalError()
    }

    @available(*, unavailable, message: "Readium CSS v2 has no themes, use textColor, backgroundColor, linkColor and visitedColor instead")
    var theme: Theme? {
        fatalError()
    }
}
