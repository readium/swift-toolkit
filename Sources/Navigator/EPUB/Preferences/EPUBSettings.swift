//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Setting values of the `EPUBNavigatorViewController`.
///
/// See `EPUBPreferences`
public struct EPUBSettings: ConfigurableSettings, Sendable {
    public var backgroundColor: Color?
    /// Number of reflowable columns to display (one-page view or two-page spread).
    /// `0` means automatic column count.
    public var columnCount: Int
    public var fit: Fit
    public var fontFamily: FontFamily?
    public var fontSize: Double
    public var fontWeight: Double?
    public var hyphens: Bool?
    public var blendImages: Bool?
    public var darkenImages: Double?
    public var invertImages: Double?
    public var invertGaiji: Double?
    public var language: Language?
    public var letterSpacing: Double?
    public var ligatures: Bool?
    public var lineLength: Double
    public var lineHeight: Double?
    public var noRuby: Bool
    public var offsetFirstPage: Bool?
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
        columnCount: Int,
        fit: Fit,
        fontFamily: FontFamily?,
        fontSize: Double,
        fontWeight: Double?,
        hyphens: Bool?,
        blendImages: Bool?,
        darkenImages: Double?,
        invertImages: Double?,
        invertGaiji: Double?,
        language: Language?,
        letterSpacing: Double?,
        ligatures: Bool?,
        lineLength: Double,
        lineHeight: Double?,
        noRuby: Bool = false,
        offsetFirstPage: Bool?,
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
        self.fit = fit
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.hyphens = hyphens
        self.blendImages = blendImages
        self.darkenImages = darkenImages
        self.invertImages = invertImages
        self.invertGaiji = invertGaiji
        self.language = language
        self.letterSpacing = letterSpacing
        self.ligatures = ligatures
        self.lineLength = lineLength
        self.lineHeight = lineHeight
        self.noRuby = noRuby
        self.offsetFirstPage = offsetFirstPage
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

        // We disable pagination with vertical text, because CSS columns don't support it properly.
        // See https://github.com/readium/swift-toolkit/discussions/370
        if verticalText {
            scroll = true
        }

        let columnCount = preferences.columnCount ?? defaults.columnCount ?? 0
        let fit = preferences.fit ?? defaults.fit ?? .auto
        let fontSize = preferences.fontSize ?? defaults.fontSize ?? 1.0
        let fontWeight = preferences.fontWeight ?? defaults.fontWeight
        let hyphens = preferences.hyphens ?? defaults.hyphens
        let blendImages = preferences.blendImages ?? defaults.blendImages
        let darkenImages = preferences.darkenImages ?? defaults.darkenImages
        let invertImages = preferences.invertImages ?? defaults.invertImages
        let invertGaiji = preferences.invertGaiji ?? defaults.invertGaiji
        let letterSpacing = preferences.letterSpacing ?? defaults.letterSpacing
        let lineLength = preferences.lineLength ?? defaults.lineLength ?? 1.0
        let ligatures = preferences.ligatures ?? defaults.ligatures
        let lineHeight = preferences.lineHeight ?? defaults.lineHeight
        let noRuby = preferences.noRuby ?? defaults.noRuby ?? false
        let offsetFirstPage = preferences.offsetFirstPage ?? defaults.offsetFirstPage
        let pageMargins = preferences.pageMargins ?? defaults.pageMargins ?? 1.0
        let paragraphIndent = preferences.paragraphIndent ?? defaults.paragraphIndent
        let paragraphSpacing = preferences.paragraphSpacing ?? defaults.paragraphSpacing
        let publisherStyles = preferences.publisherStyles ?? defaults.publisherStyles ?? true
        let spread = preferences.spread ?? defaults.spread ?? .auto
        let textAlign = preferences.textAlign ?? defaults.textAlign
        let textNormalization = preferences.textNormalization ?? defaults.textNormalization ?? false
        let theme = preferences.theme ?? .light
        let typeScale = preferences.typeScale ?? defaults.typeScale
        let wordSpacing = preferences.wordSpacing ?? defaults.wordSpacing

        self.init(
            backgroundColor: preferences.backgroundColor,
            columnCount: columnCount,
            fit: fit,
            fontFamily: preferences.fontFamily,
            fontSize: fontSize,
            fontWeight: fontWeight,
            hyphens: hyphens,
            blendImages: blendImages,
            darkenImages: darkenImages,
            invertImages: invertImages,
            invertGaiji: invertGaiji,
            language: language,
            letterSpacing: letterSpacing,
            ligatures: ligatures,
            lineLength: lineLength,
            lineHeight: lineHeight,
            noRuby: noRuby,
            offsetFirstPage: offsetFirstPage,
            pageMargins: pageMargins,
            paragraphIndent: paragraphIndent,
            paragraphSpacing: paragraphSpacing,
            publisherStyles: publisherStyles,
            readingProgression: readingProgression,
            scroll: scroll,
            spread: spread,
            textAlign: textAlign,
            textColor: preferences.textColor,
            textNormalization: textNormalization,
            theme: theme,
            typeScale: typeScale,
            verticalText: verticalText,
            wordSpacing: wordSpacing
        )
    }
}

/// Default setting values for the EPUB navigator.
///
/// These values will be used when no publication metadata or user preference
/// takes precedence.
///
/// See `EPUBPreferences`.
public struct EPUBDefaults: Sendable {
    public var columnCount: Int?
    public var fit: Fit?
    public var fontSize: Double?
    public var fontWeight: Double?
    public var hyphens: Bool?
    public var blendImages: Bool?
    public var darkenImages: Double?
    public var invertImages: Double?
    public var invertGaiji: Double?
    public var language: Language?
    public var letterSpacing: Double?
    public var ligatures: Bool?
    public var lineLength: Double?
    public var lineHeight: Double?
    public var noRuby: Bool?
    public var offsetFirstPage: Bool?
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
        columnCount: Int? = nil,
        fit: Fit? = nil,
        fontSize: Double? = nil,
        fontWeight: Double? = nil,
        hyphens: Bool? = nil,
        blendImages: Bool? = nil,
        darkenImages: Double? = nil,
        invertImages: Double? = nil,
        invertGaiji: Double? = nil,
        language: Language? = nil,
        letterSpacing: Double? = nil,
        ligatures: Bool? = nil,
        lineLength: Double? = nil,
        lineHeight: Double? = nil,
        noRuby: Bool? = nil,
        offsetFirstPage: Bool? = nil,
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
        self.fit = fit
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.hyphens = hyphens
        self.blendImages = blendImages
        self.darkenImages = darkenImages
        self.invertImages = invertImages
        self.invertGaiji = invertGaiji
        self.language = language
        self.letterSpacing = letterSpacing
        self.ligatures = ligatures
        self.lineLength = lineLength
        self.lineHeight = lineHeight
        self.noRuby = noRuby
        self.offsetFirstPage = offsetFirstPage
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
