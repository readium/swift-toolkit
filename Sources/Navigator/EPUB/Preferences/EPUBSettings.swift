//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Setting values of the `EPUBNavigatorViewController`.
///
/// The navigator resolves them from the submitted `EPUBPreferences`. Use
/// `EPUBNavigatorViewController.settings(for:)` to get the settings resolved
/// from given preferences without submitting them, for example to check
/// which settings are effective with `isEffective(_:)`.
///
/// See `EPUBPreferences`
public struct EPUBSettings: ConfigurableSettings, Sendable {
    public internal(set) var backgroundColor: Color?
    public internal(set) var blendImages: Bool
    public internal(set) var columnCount: Int?
    public internal(set) var darkenImages: Double?
    public internal(set) var fit: Fit
    public internal(set) var fontFamily: FontFamily?
    public internal(set) var fontSize: Double
    public internal(set) var fontWeight: Double?
    public internal(set) var fontWidth: Double?
    public internal(set) var hyphens: Bool?
    public internal(set) var invertGaiji: Bool
    public internal(set) var invertImages: Bool
    public internal(set) var language: Language?
    public internal(set) var letterSpacing: Double?
    public internal(set) var ligatures: Bool?
    public internal(set) var lineHeight: Double?
    public internal(set) var linkColor: Color?
    public internal(set) var maximalLineLength: Double?
    public internal(set) var minimalLineLength: Double?
    public internal(set) var noRuby: Bool
    public internal(set) var offsetFirstPage: Bool?
    public internal(set) var optimalLineLength: Double
    public internal(set) var pageMargins: Double
    public internal(set) var paragraphIndent: Double?
    public internal(set) var paragraphSpacing: Double?
    public internal(set) var readingProgression: ReadingProgression
    public internal(set) var scroll: Bool
    public internal(set) var spread: Spread
    public internal(set) var textAlign: TextAlignment?
    public internal(set) var textColor: Color?
    public internal(set) var textNormalization: Bool
    public internal(set) var verticalText: Bool
    public internal(set) var visitedColor: Color?
    public internal(set) var wordSpacing: Double?

    public var effectiveBackgroundColor: Color {
        backgroundColor ?? ReadiumCSS.defaultBackgroundColor
    }

    /// Readium CSS layout, derived from the `language`, `readingProgression`
    /// and `verticalText` settings.
    var cssLayout: CSSLayout {
        CSSLayout(verticalText: verticalText, language: language, readingProgression: readingProgression)
    }

    /// Layouts of the resources rendered by the navigator.
    let layouts: EPUBLayouts

    init(
        layouts: EPUBLayouts = .reflowable,
        backgroundColor: Color?,
        blendImages: Bool,
        columnCount: Int?,
        darkenImages: Double?,
        fit: Fit,
        fontFamily: FontFamily?,
        fontSize: Double,
        fontWeight: Double?,
        fontWidth: Double?,
        hyphens: Bool?,
        invertGaiji: Bool,
        invertImages: Bool,
        language: Language?,
        letterSpacing: Double?,
        ligatures: Bool?,
        lineHeight: Double?,
        linkColor: Color?,
        maximalLineLength: Double?,
        minimalLineLength: Double?,
        noRuby: Bool,
        offsetFirstPage: Bool?,
        optimalLineLength: Double,
        pageMargins: Double,
        paragraphIndent: Double?,
        paragraphSpacing: Double?,
        readingProgression: ReadingProgression,
        scroll: Bool,
        spread: Spread,
        textAlign: TextAlignment?,
        textColor: Color?,
        textNormalization: Bool,
        verticalText: Bool,
        visitedColor: Color?,
        wordSpacing: Double?
    ) {
        self.backgroundColor = backgroundColor
        self.blendImages = blendImages
        self.columnCount = EPUBPreferences.validColumnCount(columnCount)
        self.darkenImages = darkenImages?.clamped(to: EPUBPreferences.imageFilterRange)
        self.fit = fit
        self.fontFamily = fontFamily
        self.fontSize = fontSize.positiveOrNil ?? 1.0
        self.fontWeight = fontWeight?.clamped(to: EPUBPreferences.fontWeightRange)
        self.fontWidth = fontWidth?.clamped(to: EPUBPreferences.fontWidthRange)
        self.hyphens = hyphens
        self.invertGaiji = invertGaiji
        self.invertImages = invertImages
        self.language = language
        self.letterSpacing = letterSpacing.map { max($0, 0) }
        self.ligatures = ligatures
        self.lineHeight = lineHeight
        self.linkColor = linkColor
        self.maximalLineLength = maximalLineLength?.positiveOrNil
        self.minimalLineLength = minimalLineLength?.positiveOrNil
        self.noRuby = noRuby
        self.offsetFirstPage = offsetFirstPage
        self.optimalLineLength = optimalLineLength.positiveOrNil ?? 1.0
        self.pageMargins = max(pageMargins, 0)
        self.paragraphIndent = paragraphIndent
        self.paragraphSpacing = paragraphSpacing.map { max($0, 0) }
        self.readingProgression = readingProgression
        self.scroll = scroll
        self.spread = spread
        self.textAlign = textAlign
        self.textColor = textColor
        self.textNormalization = textNormalization
        self.verticalText = verticalText
        self.visitedColor = visitedColor
        self.wordSpacing = wordSpacing.map { max($0, 0) }
        self.layouts = layouts
    }

    /// Resolves the settings from the given `preferences`, with the
    /// publication `metadata` and the `layouts` of the rendered reading order.
    ///
    /// A preference takes precedence over the publication metadata, which
    /// takes precedence over the `defaults`. Some settings are also derived
    /// from others, for example vertical text forces the scroll mode.
    init(preferences: EPUBPreferences, defaults: EPUBDefaults, metadata: Metadata, layouts: EPUBLayouts = .reflowable) {
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

        let columnCount = EPUBPreferences.validColumnCount(preferences.columnCount) ?? defaults.columnCount
        let fit = preferences.fit ?? defaults.fit ?? .auto
        let fontSize = preferences.fontSize?.positiveOrNil ?? defaults.fontSize ?? 1.0
        let fontWeight = preferences.fontWeight ?? defaults.fontWeight
        let fontWidth = preferences.fontWidth ?? defaults.fontWidth
        let hyphens = preferences.hyphens ?? defaults.hyphens
        let letterSpacing = preferences.letterSpacing ?? defaults.letterSpacing
        let ligatures = preferences.ligatures ?? defaults.ligatures
        let lineHeight = preferences.lineHeight ?? defaults.lineHeight
        let maximalLineLength = preferences.maximalLineLength?.positiveOrNil ?? defaults.maximalLineLength
        let minimalLineLength = preferences.minimalLineLength?.positiveOrNil ?? defaults.minimalLineLength
        let noRuby = preferences.noRuby ?? defaults.noRuby ?? false
        let offsetFirstPage = preferences.offsetFirstPage ?? defaults.offsetFirstPage
        let optimalLineLength = preferences.optimalLineLength?.positiveOrNil ?? defaults.optimalLineLength ?? 1.0
        let pageMargins = preferences.pageMargins ?? defaults.pageMargins ?? 1.0
        let paragraphIndent = preferences.paragraphIndent ?? defaults.paragraphIndent
        let paragraphSpacing = preferences.paragraphSpacing ?? defaults.paragraphSpacing
        let spread = preferences.spread ?? defaults.spread ?? .auto
        let textAlign = preferences.textAlign ?? defaults.textAlign
        let textNormalization = preferences.textNormalization ?? defaults.textNormalization ?? false
        let wordSpacing = preferences.wordSpacing ?? defaults.wordSpacing

        self.init(
            layouts: layouts,
            backgroundColor: preferences.backgroundColor,
            blendImages: preferences.blendImages ?? false,
            columnCount: columnCount,
            darkenImages: preferences.darkenImages,
            fit: fit,
            fontFamily: preferences.fontFamily,
            fontSize: fontSize,
            fontWeight: fontWeight,
            fontWidth: fontWidth,
            hyphens: hyphens,
            invertGaiji: preferences.invertGaiji ?? false,
            invertImages: preferences.invertImages ?? false,
            language: language,
            letterSpacing: letterSpacing,
            ligatures: ligatures,
            lineHeight: lineHeight,
            linkColor: preferences.linkColor,
            maximalLineLength: maximalLineLength,
            minimalLineLength: minimalLineLength,
            noRuby: noRuby,
            offsetFirstPage: offsetFirstPage,
            optimalLineLength: optimalLineLength,
            pageMargins: pageMargins,
            paragraphIndent: paragraphIndent,
            paragraphSpacing: paragraphSpacing,
            readingProgression: readingProgression,
            scroll: scroll,
            spread: spread,
            textAlign: textAlign,
            textColor: preferences.textColor,
            textNormalization: textNormalization,
            verticalText: verticalText,
            visitedColor: preferences.visitedColor,
            wordSpacing: wordSpacing
        )
    }
}

public extension EPUBSettings {
    /// Indicates whether the given `setting` would take effect if it was set,
    /// see `ConfigurableSettings.isEffective(_:)`. A setting left unset keeps
    /// the styles of the publication.
    ///
    /// The rules of each setting are:
    /// - Always effective: `backgroundColor`, `language`,
    ///   `readingProgression`.
    /// - When the publication contains fixed-layout resources: `fit`,
    ///   `spread`, and `offsetFirstPage` when `spread` is not `.never`.
    /// - When the publication contains reflowable resources, and:
    ///   - always: `blendImages`, `darkenImages`, `fontFamily`, `fontSize`,
    ///     `fontWeight`, `fontWidth`, `invertGaiji`, `invertImages`,
    ///     `lineHeight`, `linkColor`, `maximalLineLength`, `pageMargins`,
    ///     `paragraphSpacing`, `textColor`, `verticalText`, `visitedColor`.
    ///   - `columnCount`: when `scroll` is off.
    ///   - `optimalLineLength`: when `scroll` is off and `columnCount` is
    ///     `nil` (automatic).
    ///   - `minimalLineLength`: when `scroll` is off and `columnCount` is
    ///     greater than 1.
    ///   - `scroll`: when `verticalText` is off, as vertical text is always
    ///     scrolled.
    ///   - `hyphens`, `textNormalization`: with an LTR layout.
    ///   - `ligatures`, `paragraphIndent`, `textAlign`, `wordSpacing`: with
    ///     an LTR or RTL layout.
    ///   - `letterSpacing`: with an LTR or CJK layout.
    ///   - `noRuby`: with a CJK layout.
    ///
    /// The layout (LTR, RTL or CJK) depends on the `language`,
    /// `readingProgression` and `verticalText` settings.
    ///
    /// - Parameter setting: Key path of a stored setting, e.g. `\.hyphens`.
    ///   Other key paths, such as `\.effectiveBackgroundColor`, are a
    ///   programming error.
    func isEffective(_ setting: PartialKeyPath<EPUBSettings>) -> Bool {
        let reflowable = layouts.contains(.reflowable)
        let fixed = layouts.contains(.fixed)
        let stylesheets = cssLayout.stylesheets

        switch setting {
        case \.backgroundColor, \.language, \.readingProgression:
            return true
        case \.fit, \.spread:
            return fixed
        case \.offsetFirstPage:
            return fixed && spread != .never
        case \.blendImages, \.darkenImages, \.fontFamily, \.fontSize,
             \.fontWeight, \.fontWidth, \.invertGaiji, \.invertImages,
             \.lineHeight, \.linkColor, \.maximalLineLength, \.pageMargins,
             \.paragraphSpacing, \.textColor, \.verticalText, \.visitedColor:
            return reflowable
        case \.columnCount:
            return reflowable && !scroll
        case \.optimalLineLength:
            return reflowable && !scroll && columnCount == nil
        case \.minimalLineLength:
            return reflowable && !scroll && (columnCount ?? 1) > 1
        case \.scroll:
            return reflowable && !verticalText
        case \.hyphens, \.textNormalization:
            return reflowable && stylesheets == .default
        case \.ligatures, \.paragraphIndent, \.textAlign, \.wordSpacing:
            return reflowable && [.default, .rtl].contains(stylesheets)
        case \.letterSpacing:
            return reflowable && [.default, .cjkHorizontal, .cjkVertical].contains(stylesheets)
        case \.noRuby:
            return reflowable && stylesheets.isCJK
        default:
            preconditionFailure("\(setting) is not a stored setting of EPUBSettings")
        }
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
    public var fontWidth: Double?
    public var hyphens: Bool?
    public var language: Language?
    public var letterSpacing: Double?
    public var ligatures: Bool?
    public var lineHeight: Double?
    /// `1.0` by default, which limits the lines to the maximal line length.
    /// Set it to `nil` to let the lines take all the available width.
    public var maximalLineLength: Double?
    public var minimalLineLength: Double?
    public var noRuby: Bool?
    public var offsetFirstPage: Bool?
    public var optimalLineLength: Double?
    public var pageMargins: Double?
    public var paragraphIndent: Double?
    public var paragraphSpacing: Double?
    public var readingProgression: ReadingProgression?
    public var scroll: Bool?
    public var spread: Spread?
    public var textAlign: TextAlignment?
    public var textNormalization: Bool?
    public var wordSpacing: Double?

    public init(
        columnCount: Int? = nil,
        fit: Fit? = nil,
        fontSize: Double? = nil,
        fontWeight: Double? = nil,
        fontWidth: Double? = nil,
        hyphens: Bool? = nil,
        language: Language? = nil,
        letterSpacing: Double? = nil,
        ligatures: Bool? = nil,
        lineHeight: Double? = nil,
        // Not a fallback in `EPUBSettings`, so that `nil` removes the limit.
        maximalLineLength: Double? = 1.0,
        minimalLineLength: Double? = nil,
        noRuby: Bool? = nil,
        offsetFirstPage: Bool? = nil,
        optimalLineLength: Double? = nil,
        pageMargins: Double? = nil,
        paragraphIndent: Double? = nil,
        paragraphSpacing: Double? = nil,
        readingProgression: ReadingProgression? = nil,
        scroll: Bool? = nil,
        spread: Spread? = nil,
        textAlign: TextAlignment? = nil,
        textNormalization: Bool? = nil,
        wordSpacing: Double? = nil
    ) {
        self.columnCount = EPUBPreferences.validColumnCount(columnCount)
        self.fit = fit
        self.fontSize = fontSize?.positiveOrNil
        self.fontWeight = fontWeight?.clamped(to: EPUBPreferences.fontWeightRange)
        self.fontWidth = fontWidth?.clamped(to: EPUBPreferences.fontWidthRange)
        self.hyphens = hyphens
        self.language = language
        self.letterSpacing = letterSpacing.map { max($0, 0) }
        self.ligatures = ligatures
        self.lineHeight = lineHeight
        self.maximalLineLength = maximalLineLength?.positiveOrNil
        self.minimalLineLength = minimalLineLength?.positiveOrNil
        self.noRuby = noRuby
        self.offsetFirstPage = offsetFirstPage
        self.optimalLineLength = optimalLineLength?.positiveOrNil
        self.pageMargins = pageMargins.map { max($0, 0) }
        self.paragraphIndent = paragraphIndent
        self.paragraphSpacing = paragraphSpacing.map { max($0, 0) }
        self.readingProgression = readingProgression
        self.scroll = scroll
        self.spread = spread
        self.textAlign = textAlign
        self.textNormalization = textNormalization
        self.wordSpacing = wordSpacing.map { max($0, 0) }
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
