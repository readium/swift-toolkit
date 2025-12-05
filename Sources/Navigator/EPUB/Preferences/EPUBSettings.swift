//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Setting values of the `EPUBNavigatorViewController`.
///
/// See `EPUBPreferences`
public struct EPUBSettings: ConfigurableSettings {
    public var backgroundColor: Color?
    public var columnCount: ColumnCount
    public var fontFamily: FontFamily?
    public var fontSize: Double
    public var fontWeight: Double?
    public var hyphens: Bool?
    public var imageFilter: ImageFilter?
    public var language: Language?
    public var letterSpacing: Double?
    public var ligatures: Bool?
    public var lineHeight: Double?
    public var pageMargins: Double
    public var paragraphIndent: Double?
    public var paragraphSpacing: Double?
    public var publisherStyles: Bool
    public var readingProgression: ReadingProgression
    public var scroll: Bool
    public var spread: Spread
    public var textAlign: TextAlignment?
    public var textColor: Color?
    public var textNormalization: Bool
    public var theme: Theme
    public var typeScale: Double?
    public var verticalText: Bool
    public var wordSpacing: Double?

    public var effectiveBackgroundColor: Color {
        backgroundColor ?? theme.backgroundColor
    }

    let cssLayout: CSSLayout

    public init(
        backgroundColor: Color?,
        columnCount: ColumnCount,
        fontFamily: FontFamily?,
        fontSize: Double,
        fontWeight: Double?,
        hyphens: Bool?,
        imageFilter: ImageFilter?,
        language: Language?,
        letterSpacing: Double?,
        ligatures: Bool?,
        lineHeight: Double?,
        pageMargins: Double,
        paragraphIndent: Double?,
        paragraphSpacing: Double?,
        publisherStyles: Bool,
        readingProgression: ReadingProgression,
        scroll: Bool,
        spread: Spread,
        textAlign: TextAlignment?,
        textColor: Color?,
        textNormalization: Bool,
        theme: Theme,
        typeScale: Double?,
        verticalText: Bool,
        wordSpacing: Double?
    ) {
        self.backgroundColor = backgroundColor
        self.columnCount = columnCount
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.hyphens = hyphens
        self.imageFilter = imageFilter
        self.language = language
        self.letterSpacing = letterSpacing
        self.ligatures = ligatures
        self.lineHeight = lineHeight
        self.pageMargins = pageMargins
        self.paragraphIndent = paragraphIndent
        self.paragraphSpacing = paragraphSpacing
        self.publisherStyles = publisherStyles
        self.readingProgression = readingProgression
        self.scroll = scroll
        self.spread = spread
        self.textAlign = textAlign
        self.textColor = textColor
        self.textNormalization = textNormalization
        self.theme = theme
        self.typeScale = typeScale
        self.verticalText = verticalText
        self.wordSpacing = wordSpacing
        cssLayout = CSSLayout(verticalText: verticalText, language: language, readingProgression: readingProgression)
    }

    init(preferences: EPUBPreferences, defaults: EPUBDefaults, metadata: Metadata) {
        // Compute language according to the following rule:
        // preference value > metadata value > default value > null
        let language = preferences.language
            ?? metadata.language
            ?? defaults.language

        // Compute readingProgression according to the following rule:
        // preference value > value inferred from language preference > metadata value
        // value inferred from metadata languages > default value >
        // value inferred from default language > LTR
        let readingProgression: ReadingProgression =
            preferences.readingProgression
                ?? preferences.language?.readingProgression
                ?? ReadingProgression(metadata.readingProgression)
                ?? metadata.language?.readingProgression
                ?? defaults.readingProgression
                ?? defaults.language?.readingProgression
                ?? .ltr

        // Compute `verticalText` according to the following rule:
        // preference value > value computed from resolved language > false
        let verticalText = preferences.verticalText
            ?? language?.verticalText(for: readingProgression)
            ?? false

        var scroll = preferences.scroll
            ?? defaults.scroll
            ?? false

        /// We disable pagination with vertical text, because CSS columns don't support it properly.
        /// See https://github.com/readium/swift-toolkit/discussions/370
        if verticalText {
            scroll = true
        }

        self.init(
            backgroundColor: preferences.backgroundColor,
            columnCount: preferences.columnCount
                ?? defaults.columnCount
                ?? .auto,
            fontFamily: preferences.fontFamily,
            fontSize: preferences.fontSize
                ?? defaults.fontSize
                ?? 1.0,
            fontWeight: preferences.fontWeight
                ?? defaults.fontWeight,
            hyphens: preferences.hyphens
                ?? defaults.hyphens,
            imageFilter: preferences.imageFilter
                ?? defaults.imageFilter,
            language: language,
            letterSpacing: preferences.letterSpacing
                ?? defaults.letterSpacing,
            ligatures: preferences.ligatures
                ?? defaults.ligatures,
            lineHeight: preferences.lineHeight
                ?? defaults.lineHeight,
            pageMargins: preferences.pageMargins
                ?? defaults.pageMargins
                ?? 1.0,
            paragraphIndent: preferences.paragraphIndent
                ?? defaults.paragraphIndent,
            paragraphSpacing: preferences.paragraphSpacing
                ?? defaults.paragraphSpacing,
            publisherStyles: preferences.publisherStyles
                ?? defaults.publisherStyles
                ?? true,
            readingProgression: readingProgression,
            scroll: scroll,
            spread: preferences.spread
                ?? defaults.spread
                ?? .auto,
            textAlign: preferences.textAlign
                ?? defaults.textAlign,
            textColor: preferences.textColor,
            textNormalization: preferences.textNormalization
                ?? defaults.textNormalization
                ?? false,
            theme: preferences.theme
                ?? .light,
            typeScale: preferences.typeScale
                ?? defaults.typeScale,
            verticalText: verticalText,
            wordSpacing: preferences.wordSpacing
                ?? defaults.wordSpacing
        )
    }
}

/// Default setting values for the EPUB navigator.
///
/// These values will be used when no publication metadata or user preference
/// takes precedence.
///
/// See `EPUBPreferences`.
public struct EPUBDefaults {
    public var columnCount: ColumnCount?
    public var fontSize: Double?
    public var fontWeight: Double?
    public var hyphens: Bool?
    public var imageFilter: ImageFilter?
    public var language: Language?
    public var letterSpacing: Double?
    public var ligatures: Bool?
    public var lineHeight: Double?
    public var pageMargins: Double?
    public var paragraphIndent: Double?
    public var paragraphSpacing: Double?
    public var publisherStyles: Bool?
    public var readingProgression: ReadingProgression?
    public var scroll: Bool?
    public var spread: Spread?
    public var textAlign: TextAlignment?
    public var textNormalization: Bool?
    public var typeScale: Double?
    public var wordSpacing: Double?

    public init(
        columnCount: ColumnCount? = nil,
        fontSize: Double? = nil,
        fontWeight: Double? = nil,
        hyphens: Bool? = nil,
        imageFilter: ImageFilter? = nil,
        language: Language? = nil,
        letterSpacing: Double? = nil,
        ligatures: Bool? = nil,
        lineHeight: Double? = nil,
        pageMargins: Double? = nil,
        paragraphIndent: Double? = nil,
        paragraphSpacing: Double? = nil,
        publisherStyles: Bool? = nil,
        readingProgression: ReadingProgression? = nil,
        scroll: Bool? = nil,
        spread: Spread? = nil,
        textAlign: TextAlignment? = nil,
        textNormalization: Bool? = nil,
        typeScale: Double? = nil,
        wordSpacing: Double? = nil
    ) {
        self.columnCount = columnCount
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.hyphens = hyphens
        self.imageFilter = imageFilter
        self.language = language
        self.letterSpacing = letterSpacing
        self.ligatures = ligatures
        self.lineHeight = lineHeight
        self.pageMargins = pageMargins
        self.paragraphIndent = paragraphIndent
        self.paragraphSpacing = paragraphSpacing
        self.publisherStyles = publisherStyles
        self.readingProgression = readingProgression
        self.scroll = scroll
        self.spread = spread
        self.textAlign = textAlign
        self.textNormalization = textNormalization
        self.typeScale = typeScale
        self.wordSpacing = wordSpacing
    }
}

private extension Language {
    var readingProgression: ReadingProgression {
        isRTL ? .rtl : .ltr
    }

    func verticalText(for readingProgression: ReadingProgression) -> Bool {
        isCJK && readingProgression == .rtl
    }
}
