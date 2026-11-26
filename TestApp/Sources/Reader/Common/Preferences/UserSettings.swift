//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumNavigator
import ReadiumShared

/// User settings of a reader, owned and persisted by the Test App.
///
/// The navigator preferences are derived from them with `preferences()`
/// before being submitted. The settings are split into a part specific to
/// each book and a part shared by all the books of the same format.
nonisolated protocol UserSettings: Hashable, Sendable {
    associatedtype Preferences: ConfigurablePreferences
    associatedtype NavigatorSettings: ConfigurableSettings
    associatedtype BookSettings: UserSettingsPart
    associatedtype SharedSettings: UserSettingsPart

    /// Key of the shared settings in the `UserDefaults`.
    static var storageKey: String { get }

    var book: BookSettings { get }
    var shared: SharedSettings { get }

    init(book: BookSettings, shared: SharedSettings)

    /// Returns the navigator preferences to submit.
    func preferences() -> Preferences

    /// Resolves the settings the navigator applies to `publication` with
    /// these user settings, to tell which ones are effective.
    func navigatorSettings(for publication: Publication) -> NavigatorSettings
}

nonisolated extension UserSettings {
    /// Settings with no value set.
    static var empty: Self {
        Self(book: BookSettings(), shared: SharedSettings())
    }
}

/// A part of `UserSettings`, persisted as JSON.
nonisolated protocol UserSettingsPart: Codable, Hashable, Sendable {
    init()
}

// MARK: - EPUB

nonisolated struct EPUBUserSettings: UserSettings {
    static let storageKey = "epub"

    /// Defaults given to the navigator, and to the settings resolved to tell
    /// which ones are effective.
    static let defaults = EPUBDefaults()

    nonisolated struct BookSettings: UserSettingsPart {
        var language: String?
        var offsetFirstPage: Bool?
        var readingProgression: String?
        var spread: String?
        var verticalText: Bool?
    }

    nonisolated struct SharedSettings: UserSettingsPart {
        var theme: Theme = .publisher
        var blendImages: Bool?
        var columnCount: Int?
        var darkenImages: Double?
        var fit: String?
        var fontFamily: String?
        var fontSize: Double?
        var fontWeight: Double?
        var fontWidth: Double?
        var hyphens: Bool?
        var invertGaiji: Bool?
        var invertImages: Bool?
        var letterSpacing: Double?
        var ligatures: Bool?
        var lineHeight: Double?
        var maximalLineLength: Double?
        var minimalLineLength: Double?
        var noRuby: Bool?
        var optimalLineLength: Double?
        var pageMargins: Double?
        var paragraphIndent: Double?
        var paragraphSpacing: Double?
        var scroll: Bool?
        var textAlign: String?
        var textNormalization: Bool?
        var wordSpacing: Double?
    }

    /// Colors of the publication, applied together.
    nonisolated enum Theme: Codable, Hashable, Sendable {
        /// Keeps the colors of the publication.
        case publisher
        case sepia
        case dark
        /// Colors which match no other theme, as packed integers.
        case custom(text: Int?, background: Int?, link: Int?, visited: Int?)

        var readerTheme: ReaderTheme {
            switch self {
            case .publisher:
                return .light
            case .sepia:
                return .sepia
            case .dark:
                return .dark
            case let .custom(text, background, link, visited):
                return ReaderTheme(
                    name: "Custom",
                    textColor: text.map(Color.init(rawValue:)),
                    backgroundColor: background.map(Color.init(rawValue:)),
                    linkColor: link.map(Color.init(rawValue:)),
                    visitedColor: visited.map(Color.init(rawValue:))
                )
            }
        }
    }

    var book: BookSettings
    var shared: SharedSettings
}

nonisolated extension EPUBUserSettings {
    func preferences() -> EPUBPreferences {
        let colors = shared.theme.readerTheme
        return EPUBPreferences(
            backgroundColor: colors.backgroundColor,
            blendImages: shared.blendImages,
            columnCount: shared.columnCount,
            darkenImages: shared.darkenImages,
            fit: shared.fit.flatMap(Fit.init(rawValue:)),
            fontFamily: shared.fontFamily.map(FontFamily.init(rawValue:)),
            fontSize: shared.fontSize,
            fontWeight: shared.fontWeight,
            fontWidth: shared.fontWidth,
            hyphens: shared.hyphens,
            invertGaiji: shared.invertGaiji,
            invertImages: shared.invertImages,
            language: book.language.map { Language($0) },
            letterSpacing: shared.letterSpacing,
            ligatures: shared.ligatures,
            lineHeight: shared.lineHeight,
            linkColor: colors.linkColor,
            maximalLineLength: shared.maximalLineLength,
            minimalLineLength: shared.minimalLineLength,
            noRuby: shared.noRuby,
            offsetFirstPage: book.offsetFirstPage,
            optimalLineLength: shared.optimalLineLength,
            pageMargins: shared.pageMargins,
            paragraphIndent: shared.paragraphIndent,
            paragraphSpacing: shared.paragraphSpacing,
            readingProgression: book.readingProgression.flatMap(ReadingProgression.init(rawValue:)),
            scroll: shared.scroll,
            spread: book.spread.flatMap(Spread.init(rawValue:)),
            textAlign: shared.textAlign.flatMap(TextAlignment.init(rawValue:)),
            textColor: colors.textColor,
            textNormalization: shared.textNormalization,
            verticalText: book.verticalText,
            visitedColor: colors.visitedColor,
            wordSpacing: shared.wordSpacing
        )
    }

    func navigatorSettings(for publication: Publication) -> EPUBSettings {
        EPUBSettings(publication: publication, preferences: preferences(), defaults: Self.defaults)
    }
}

// MARK: - PDF

nonisolated struct PDFUserSettings: UserSettings {
    static let storageKey = "pdf"

    /// Defaults given to the navigator, and to the settings resolved to tell
    /// which ones are effective.
    static let defaults = PDFDefaults()

    nonisolated struct BookSettings: UserSettingsPart {
        var offsetFirstPage: Bool?
        var readingProgression: String?
    }

    nonisolated struct SharedSettings: UserSettingsPart {
        var backgroundColor: Int?
        var fit: String?
        var pageSpacing: Double?
        var scroll: Bool?
        var scrollAxis: String?
        var spread: String?
        var visibleScrollbar: Bool?
    }

    var book: BookSettings
    var shared: SharedSettings
}

nonisolated extension PDFUserSettings {
    func preferences() -> PDFPreferences {
        PDFPreferences(
            backgroundColor: shared.backgroundColor.map(Color.init(rawValue:)),
            fit: shared.fit.flatMap(Fit.init(rawValue:)),
            offsetFirstPage: book.offsetFirstPage,
            pageSpacing: shared.pageSpacing,
            readingProgression: book.readingProgression.flatMap(ReadingProgression.init(rawValue:)),
            scroll: shared.scroll,
            scrollAxis: shared.scrollAxis.flatMap(Axis.init(rawValue:)),
            spread: shared.spread.flatMap(Spread.init(rawValue:)),
            visibleScrollbar: shared.visibleScrollbar
        )
    }

    func navigatorSettings(for publication: Publication) -> PDFSettings {
        PDFSettings(publication: publication, preferences: preferences(), defaults: Self.defaults)
    }
}

// MARK: - Audio

nonisolated struct AudioUserSettings: UserSettings {
    static let storageKey = "audio"

    /// Defaults given to the navigator, and to the settings resolved to tell
    /// which ones are effective.
    static let defaults = AudioDefaults()

    /// The audio navigator has no book-specific preferences.
    nonisolated struct BookSettings: UserSettingsPart {}

    nonisolated struct SharedSettings: UserSettingsPart {
        var volume: Double?
        var speed: Double?
    }

    var book: BookSettings
    var shared: SharedSettings
}

nonisolated extension AudioUserSettings {
    func preferences() -> AudioPreferences {
        AudioPreferences(volume: shared.volume, speed: shared.speed)
    }

    func navigatorSettings(for publication: Publication) -> AudioSettings {
        AudioSettings(preferences: preferences(), defaults: Self.defaults)
    }
}
