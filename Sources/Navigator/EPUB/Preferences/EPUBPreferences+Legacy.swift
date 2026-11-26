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

        // The settings ignored with the publisher defaults were saved anyway,
        // with their default values.
        if defaults.optBool(for: .publisherDefault) == true {
            preferences.clearPublisherStylesOverrides()
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

// MARK: - Preferences serialized with Readium 3.x

/// Decodes the `EPUBPreferences` persisted with Readium 3.x, to migrate them
/// to your own settings model.
///
/// This is a snapshot of the 3.x `EPUBPreferences`, with the values as they
/// were saved. The decoding is lenient: an invalid value drops only its
/// preference. See the migration guide for the equivalent of the removed
/// preferences, such as `theme` or `publisherStyles`.
///
/// It will be removed in a future major version.
public struct LegacyEPUBPreferences: Decodable, Hashable, Sendable {
    /// Default page background color, as a packed RGB integer.
    public let backgroundColor: Int?
    /// Number of reflowable columns to display.
    public let columnCount: ColumnCount?
    /// Method for fitting the content of fixed-layout resources within the
    /// viewport.
    public let fit: Fit?
    /// Default typeface for the text.
    public let fontFamily: String?
    /// Base text font size.
    public let fontSize: Double?
    /// Default boldness for the text.
    public let fontWeight: Double?
    /// Enable hyphenation.
    public let hyphens: Bool?
    /// Filter applied to images in dark theme.
    public let imageFilter: ImageFilter?
    /// Language of the publication content, as a BCP 47 tag.
    public let language: String?
    /// Space between letters.
    public let letterSpacing: Double?
    /// Enable ligatures in Arabic.
    public let ligatures: Bool?
    /// Leading line height.
    public let lineHeight: Double?
    /// Indicates whether the first page should be displayed alone and
    /// centered instead of alongside the second page.
    public let offsetFirstPage: Bool?
    /// Factor applied to horizontal margins.
    public let pageMargins: Double?
    /// Text indentation for paragraphs.
    public let paragraphIndent: Double?
    /// Vertical margins for paragraphs.
    public let paragraphSpacing: Double?
    /// Indicates whether the original publisher styles should be observed.
    ///
    /// Many settings required this to be off.
    public let publisherStyles: Bool?
    /// Direction of the reading progression across resources.
    public let readingProgression: ReadingProgression?
    /// Indicates if the overflow of resources should be handled using
    /// scrolling instead of synthetic pagination.
    public let scroll: Bool?
    /// Indicates if the fixed-layout publication should be rendered with a
    /// synthetic spread (dual-page).
    public let spread: Spread?
    /// Page text alignment.
    public let textAlign: TextAlignment?
    /// Default page text color, as a packed RGB integer.
    public let textColor: Int?
    /// Normalize text styles to increase accessibility.
    public let textNormalization: Bool?
    /// Reader theme.
    public let theme: Theme?
    /// Scale applied to all element font sizes.
    public let typeScale: Double?
    /// Indicates whether the text should be laid out vertically.
    public let verticalText: Bool?
    /// Space between words.
    public let wordSpacing: Double?

    public enum ColumnCount: String, Decodable, Hashable, Sendable {
        case auto
        case one = "1"
        case two = "2"
    }

    public enum Fit: String, Decodable, Hashable, Sendable {
        case auto
        case page
        case width
    }

    public enum ImageFilter: String, Decodable, Hashable, Sendable {
        case darken
        case invert
    }

    public enum ReadingProgression: String, Decodable, Hashable, Sendable {
        case ltr
        case rtl
    }

    public enum Spread: String, Decodable, Hashable, Sendable {
        case auto
        case never
        case always
    }

    public enum TextAlignment: String, Decodable, Hashable, Sendable {
        case center
        case justify
        case start
        case end
        case left
        case right
    }

    public enum Theme: String, Decodable, Hashable, Sendable {
        case light
        case dark
        case sepia
    }
}

public extension LegacyEPUBPreferences {
    private enum CodingKeys: String, CodingKey {
        case backgroundColor
        case columnCount
        case fit
        case fontFamily
        case fontSize
        case fontWeight
        case hyphens
        case imageFilter
        case language
        case letterSpacing
        case ligatures
        case lineHeight
        case offsetFirstPage
        case pageMargins
        case paragraphIndent
        case paragraphSpacing
        case publisherStyles
        case readingProgression
        case scroll
        case spread
        case textAlign
        case textColor
        case textNormalization
        case theme
        case typeScale
        case verticalText
        case wordSpacing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        backgroundColor = container.decodeLeniently(Int.self, forKey: .backgroundColor)
        columnCount = container.decodeLeniently(ColumnCount.self, forKey: .columnCount)
        fit = container.decodeLeniently(Fit.self, forKey: .fit)
        fontFamily = container.decodeLeniently(String.self, forKey: .fontFamily)
        fontSize = container.decodeLeniently(Double.self, forKey: .fontSize)
        fontWeight = container.decodeLeniently(Double.self, forKey: .fontWeight)
        hyphens = container.decodeLeniently(Bool.self, forKey: .hyphens)
        imageFilter = container.decodeLeniently(ImageFilter.self, forKey: .imageFilter)
        language = container.decodeLeniently(String.self, forKey: .language)
        letterSpacing = container.decodeLeniently(Double.self, forKey: .letterSpacing)
        ligatures = container.decodeLeniently(Bool.self, forKey: .ligatures)
        lineHeight = container.decodeLeniently(Double.self, forKey: .lineHeight)
        offsetFirstPage = container.decodeLeniently(Bool.self, forKey: .offsetFirstPage)
        pageMargins = container.decodeLeniently(Double.self, forKey: .pageMargins)
        paragraphIndent = container.decodeLeniently(Double.self, forKey: .paragraphIndent)
        paragraphSpacing = container.decodeLeniently(Double.self, forKey: .paragraphSpacing)
        publisherStyles = container.decodeLeniently(Bool.self, forKey: .publisherStyles)
        readingProgression = container.decodeLeniently(ReadingProgression.self, forKey: .readingProgression)
        scroll = container.decodeLeniently(Bool.self, forKey: .scroll)
        spread = container.decodeLeniently(Spread.self, forKey: .spread)
        textAlign = container.decodeLeniently(TextAlignment.self, forKey: .textAlign)
        textColor = container.decodeLeniently(Int.self, forKey: .textColor)
        textNormalization = container.decodeLeniently(Bool.self, forKey: .textNormalization)
        theme = container.decodeLeniently(Theme.self, forKey: .theme)
        typeScale = container.decodeLeniently(Double.self, forKey: .typeScale)
        verticalText = container.decodeLeniently(Bool.self, forKey: .verticalText)
        wordSpacing = container.decodeLeniently(Double.self, forKey: .wordSpacing)
    }
}

// MARK: - Legacy settings migration (2.x)

extension EPUBPreferences {
    /// Clears the preferences which were ignored while the legacy publisher
    /// styles were enabled.
    mutating func clearPublisherStylesOverrides() {
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
    mutating func applyLegacyTheme(_ theme: LegacyTheme) {
        switch theme {
        case .light:
            break

        case .dark:
            textColor = textColor ?? nightTextColor
            backgroundColor = backgroundColor ?? nightBackgroundColor
            linkColor = linkColor ?? nightLinkColor
            visitedColor = visitedColor ?? nightVisitedColor
            // The dark theme inverted the gaiji.
            invertGaiji = true

        case .sepia:
            // The link colors of the sepia theme were the default ones.
            textColor = textColor ?? sepiaTextColor
            backgroundColor = backgroundColor ?? sepiaBackgroundColor
        }
    }
}

// MARK: - Removed preferences

public extension EPUBPreferences {
    @available(*, unavailable, message: "Not needed anymore, the preferences take effect as soon as they are set")
    var publisherStyles: Bool? {
        fatalError()
    }

    @available(*, unavailable, message: "Removed without replacement")
    var typeScale: Double? {
        fatalError()
    }

    @available(*, unavailable, message: "Use darkenImages or invertImages instead")
    var imageFilter: ImageFilter? {
        fatalError()
    }

    @available(*, unavailable, message: "Use textColor, backgroundColor, linkColor and visitedColor instead")
    var theme: Theme? {
        fatalError()
    }

    @available(*, unavailable, message: "Store the publication-specific settings in your own settings model, see the migration guide")
    func filterSharedPreferences() -> EPUBPreferences {
        fatalError()
    }

    @available(*, unavailable, message: "Store the publication-specific settings in your own settings model, see the migration guide")
    func filterPublicationPreferences() -> EPUBPreferences {
        fatalError()
    }
}

// MARK: - Removed settings

public extension EPUBSettings {
    @available(*, unavailable, message: "Not needed anymore, the preferences take effect as soon as they are set")
    var publisherStyles: Bool {
        fatalError()
    }

    @available(*, unavailable, message: "Removed without replacement")
    var typeScale: Double? {
        fatalError()
    }

    @available(*, unavailable, message: "Use darkenImages or invertImages instead")
    var imageFilter: ImageFilter? {
        fatalError()
    }

    @available(*, unavailable, message: "Use textColor, backgroundColor, linkColor and visitedColor instead")
    var theme: Theme {
        fatalError()
    }
}

// MARK: - Removed defaults

public extension EPUBDefaults {
    @available(*, unavailable, message: "Not needed anymore, the preferences take effect as soon as they are set")
    var publisherStyles: Bool? {
        fatalError()
    }

    @available(*, unavailable, message: "Removed without replacement")
    var typeScale: Double? {
        fatalError()
    }

    @available(*, unavailable, message: "The image filters have no default values anymore, use the darkenImages or invertImages preferences instead")
    var imageFilter: ImageFilter? {
        fatalError()
    }
}
