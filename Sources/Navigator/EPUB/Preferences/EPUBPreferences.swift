//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Preferences for the `EPUBNavigatorViewController`.
public struct EPUBPreferences: ConfigurablePreferences, Sendable {
    public static let empty: EPUBPreferences = .init()

    /// Default page background color.
    ///
    /// When `nil`, the background color of the publication is kept.
    public var backgroundColor: Color?

    /// Number of reflowable columns to display (one-page view or two-page
    /// spread).
    ///
    /// When `nil`, the number of columns is chosen automatically depending on
    /// the viewport size. Values lower than `1` are ignored.
    public var columnCount: Int?

    /// Method for fitting the content of fixed-layout resources within the
    /// viewport.
    ///
    /// - `auto` or `page`: Fit entire page within viewport (default).
    /// - `width`: Fit page width, allow vertical scrolling if needed.
    public var fit: Fit?

    /// Default typeface for the text.
    public var fontFamily: FontFamily?

    /// Base text font size.
    public var fontSize: Double?

    /// Default boldness for the text.
    public var fontWeight: Double?

    /// Enable hyphenation.
    public var hyphens: Bool?

    /// Blends the images with the background color.
    public var blendImages: Bool?

    /// Darkens images by the given percentage (0.0 to 1.0).
    public var darkenImages: Double?

    /// Inverts images by the given percentage (0.0 to 1.0).
    public var invertImages: Double?

    /// Inverts gaiji images by the given percentage (0.0 to 1.0).
    public var invertGaiji: Double?

    /// Language of the publication content.
    public var language: Language?

    /// Space between letters.
    public var letterSpacing: Double?

    /// Enable ligatures.
    public var ligatures: Bool?

    /// Leading line height.
    public var lineHeight: Double?

    /// Color of the hyperlinks.
    ///
    /// When `nil`, the link color of the publication is kept.
    public var linkColor: Color?

    /// Factor applied to the optimal line length of the reflowable resources,
    /// used to determine the best number of columns automatically.
    ///
    /// It is used only in paginated mode, when `columnCount` is `nil`. Values
    /// lower than or equal to `0` are ignored.
    public var optimalLineLength: Double?

    /// Factor applied to the maximal line length of the reflowable resources.
    ///
    /// When `nil` and without a default value, the lines take all the available
    /// width. Values lower than or equal to `0` are ignored.
    public var maximalLineLength: Double?

    /// Factor applied to the minimal line length of the reflowable resources,
    /// under which the number of columns is reduced.
    ///
    /// It is used only in paginated mode, when `columnCount` is greater than
    /// 1. When `nil` and without a default value, the requested number of
    /// columns is always displayed. Values lower than or equal to `0` are
    /// ignored.
    public var minimalLineLength: Double?

    /// Hiding/disabling ruby (furigana) annotations.
    public var noRuby: Bool?

    /// Indicates whether the first page should be displayed alone and centered
    /// instead of alongside the second page.
    ///
    /// This is only effective if spreads are enabled.
    public var offsetFirstPage: Bool?

    /// Factor applied to the minimal margins on each side of the lines (left
    /// and right, or top and bottom with vertical text).
    public var pageMargins: Double?

    /// Text indentation for paragraphs.
    public var paragraphIndent: Double?

    /// Vertical margins for paragraphs.
    public var paragraphSpacing: Double?

    /// Direction of the reading progression across resources.
    public var readingProgression: ReadingProgression?

    /// Indicates if the overflow of resources should be handled using
    /// scrolling instead of synthetic pagination.
    public var scroll: Bool?

    /// Indicates if the fixed-layout resources should be rendered with a
    /// synthetic spread (dual-page).
    public var spread: Spread?

    /// Page text alignment.
    public var textAlign: TextAlignment?

    /// Default page text color.
    ///
    /// When `nil`, the text color of the publication is kept.
    public var textColor: Color?

    /// Normalize text styles to increase accessibility.
    public var textNormalization: Bool?

    /// Indicates whether the text should be laid out vertically.
    ///
    /// This is used for example with CJK languages. This setting is
    /// automatically derived from the language if no preference is given.
    public var verticalText: Bool?

    /// Color of the visited hyperlinks.
    ///
    /// When `nil`, the visited link color of the publication is kept.
    public var visitedColor: Color?

    /// Space between words.
    public var wordSpacing: Double?

    public init(
        backgroundColor: Color? = nil,
        columnCount: Int? = nil,
        fit: Fit? = nil,
        fontFamily: FontFamily? = nil,
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
        lineHeight: Double? = nil,
        linkColor: Color? = nil,
        maximalLineLength: Double? = nil,
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
        textColor: Color? = nil,
        textNormalization: Bool? = nil,
        verticalText: Bool? = nil,
        visitedColor: Color? = nil,
        wordSpacing: Double? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.columnCount = columnCount.takeIf { $0 >= 1 }
        self.fit = fit
        self.fontFamily = fontFamily
        self.fontSize = fontSize.map { max($0, 0) }
        self.fontWeight = fontWeight?.clamped(to: 0.0 ... 2.5)
        self.hyphens = hyphens
        self.blendImages = blendImages
        self.darkenImages = darkenImages
        self.invertImages = invertImages
        self.invertGaiji = invertGaiji
        self.language = language
        self.letterSpacing = letterSpacing.map { max($0, 0) }
        self.ligatures = ligatures
        self.lineHeight = lineHeight
        self.linkColor = linkColor
        self.maximalLineLength = maximalLineLength.takeIf { $0 > 0 }
        self.minimalLineLength = minimalLineLength.takeIf { $0 > 0 }
        self.noRuby = noRuby
        self.offsetFirstPage = offsetFirstPage
        self.optimalLineLength = optimalLineLength.takeIf { $0 > 0 }
        self.pageMargins = pageMargins.map { max($0, 0) }
        self.paragraphIndent = paragraphIndent
        self.paragraphSpacing = paragraphSpacing.map { max($0, 0) }
        self.readingProgression = readingProgression
        self.scroll = scroll
        self.spread = [nil, .never, .always].contains(spread) ? spread : nil
        self.textAlign = textAlign
        self.textColor = textColor
        self.textNormalization = textNormalization
        self.verticalText = verticalText
        self.visitedColor = visitedColor
        self.wordSpacing = wordSpacing.map { max($0, 0) }
    }

    public func merging(_ other: EPUBPreferences) -> EPUBPreferences {
        EPUBPreferences(
            backgroundColor: other.backgroundColor ?? backgroundColor,
            columnCount: other.columnCount ?? columnCount,
            fit: other.fit ?? fit,
            fontFamily: other.fontFamily ?? fontFamily,
            fontSize: other.fontSize ?? fontSize,
            fontWeight: other.fontWeight ?? fontWeight,
            hyphens: other.hyphens ?? hyphens,
            blendImages: other.blendImages ?? blendImages,
            darkenImages: other.darkenImages ?? darkenImages,
            invertImages: other.invertImages ?? invertImages,
            invertGaiji: other.invertGaiji ?? invertGaiji,
            language: other.language ?? language,
            letterSpacing: other.letterSpacing ?? letterSpacing,
            ligatures: other.ligatures ?? ligatures,
            lineHeight: other.lineHeight ?? lineHeight,
            linkColor: other.linkColor ?? linkColor,
            maximalLineLength: other.maximalLineLength ?? maximalLineLength,
            minimalLineLength: other.minimalLineLength ?? minimalLineLength,
            noRuby: other.noRuby ?? noRuby,
            offsetFirstPage: other.offsetFirstPage ?? offsetFirstPage,
            optimalLineLength: other.optimalLineLength ?? optimalLineLength,
            pageMargins: other.pageMargins ?? pageMargins,
            paragraphIndent: other.paragraphIndent ?? paragraphIndent,
            paragraphSpacing: other.paragraphSpacing ?? paragraphSpacing,
            readingProgression: other.readingProgression ?? readingProgression,
            scroll: other.scroll ?? scroll,
            spread: other.spread ?? spread,
            textAlign: other.textAlign ?? textAlign,
            textColor: other.textColor ?? textColor,
            textNormalization: other.textNormalization ?? textNormalization,
            verticalText: other.verticalText ?? verticalText,
            visitedColor: other.visitedColor ?? visitedColor,
            wordSpacing: other.wordSpacing ?? wordSpacing
        )
    }

    /// Returns a new `EPUBPreferences` with the publication-specific preferences
    /// removed.
    public func filterSharedPreferences() -> EPUBPreferences {
        var prefs = self
        prefs.language = nil
        prefs.offsetFirstPage = nil
        prefs.readingProgression = nil
        prefs.spread = nil
        prefs.verticalText = nil
        return prefs
    }

    /// Returns a new `EPUBPreferences` keeping only the publication-specific
    /// preferences.
    public func filterPublicationPreferences() -> EPUBPreferences {
        EPUBPreferences(
            language: language,
            offsetFirstPage: offsetFirstPage,
            readingProgression: readingProgression,
            spread: spread,
            verticalText: verticalText
        )
    }
}

// MARK: - Codable

public extension EPUBPreferences {
    /// Version of the serialization format, written in the `version` key.
    ///
    /// Preferences serialized before the Readium CSS v2 upgrade (toolkit 3.x)
    /// have no version.
    internal static let codingVersion = 4

    // New properties must be added here, in `init(from:)` and in
    // `encode(to:)`, and to the round-trip fixture in `EPUBPreferencesTests`.
    private enum CodingKeys: String, CodingKey {
        case version
        case backgroundColor
        case columnCount
        case fit
        case fontFamily
        case fontSize
        case fontWeight
        case hyphens
        case blendImages
        case darkenImages
        case invertImages
        case invertGaiji
        case language
        case letterSpacing
        case ligatures
        case lineHeight
        case linkColor
        case maximalLineLength
        case minimalLineLength
        case noRuby
        case offsetFirstPage
        case optimalLineLength
        case pageMargins
        case paragraphIndent
        case paragraphSpacing
        case readingProgression
        case scroll
        case spread
        case textAlign
        case textColor
        case textNormalization
        case verticalText
        case visitedColor
        case wordSpacing
    }

    /// Decodes the preferences leniently: an invalid value drops only its
    /// preference.
    ///
    /// Preferences serialized without a version are migrated from the
    /// previous format, see `EPUBPreferences+Legacy.swift`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            backgroundColor: container.decodeLeniently(Color.self, forKey: .backgroundColor),
            columnCount: container.decodeLeniently(Int.self, forKey: .columnCount),
            fit: container.decodeLeniently(Fit.self, forKey: .fit),
            fontFamily: container.decodeLeniently(FontFamily.self, forKey: .fontFamily),
            fontSize: container.decodeLeniently(Double.self, forKey: .fontSize),
            fontWeight: container.decodeLeniently(Double.self, forKey: .fontWeight),
            hyphens: container.decodeLeniently(Bool.self, forKey: .hyphens),
            blendImages: container.decodeLeniently(Bool.self, forKey: .blendImages),
            darkenImages: container.decodeLeniently(Double.self, forKey: .darkenImages),
            invertImages: container.decodeLeniently(Double.self, forKey: .invertImages),
            invertGaiji: container.decodeLeniently(Double.self, forKey: .invertGaiji),
            language: container.decodeLeniently(Language.self, forKey: .language),
            letterSpacing: container.decodeLeniently(Double.self, forKey: .letterSpacing),
            ligatures: container.decodeLeniently(Bool.self, forKey: .ligatures),
            lineHeight: container.decodeLeniently(Double.self, forKey: .lineHeight),
            linkColor: container.decodeLeniently(Color.self, forKey: .linkColor),
            maximalLineLength: container.decodeLeniently(Double.self, forKey: .maximalLineLength),
            minimalLineLength: container.decodeLeniently(Double.self, forKey: .minimalLineLength),
            noRuby: container.decodeLeniently(Bool.self, forKey: .noRuby),
            offsetFirstPage: container.decodeLeniently(Bool.self, forKey: .offsetFirstPage),
            optimalLineLength: container.decodeLeniently(Double.self, forKey: .optimalLineLength),
            pageMargins: container.decodeLeniently(Double.self, forKey: .pageMargins),
            paragraphIndent: container.decodeLeniently(Double.self, forKey: .paragraphIndent),
            paragraphSpacing: container.decodeLeniently(Double.self, forKey: .paragraphSpacing),
            readingProgression: container.decodeLeniently(ReadingProgression.self, forKey: .readingProgression),
            scroll: container.decodeLeniently(Bool.self, forKey: .scroll),
            spread: container.decodeLeniently(Spread.self, forKey: .spread),
            textAlign: container.decodeLeniently(TextAlignment.self, forKey: .textAlign),
            textColor: container.decodeLeniently(Color.self, forKey: .textColor),
            textNormalization: container.decodeLeniently(Bool.self, forKey: .textNormalization),
            verticalText: container.decodeLeniently(Bool.self, forKey: .verticalText),
            visitedColor: container.decodeLeniently(Color.self, forKey: .visitedColor),
            wordSpacing: container.decodeLeniently(Double.self, forKey: .wordSpacing)
        )

        if container.decodeLeniently(Int.self, forKey: .version) == nil {
            try migrateUnversioned(from: decoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.codingVersion, forKey: .version)
        try container.encodeIfPresent(backgroundColor, forKey: .backgroundColor)
        try container.encodeIfPresent(columnCount, forKey: .columnCount)
        try container.encodeIfPresent(fit, forKey: .fit)
        try container.encodeIfPresent(fontFamily, forKey: .fontFamily)
        try container.encodeIfPresent(fontSize, forKey: .fontSize)
        try container.encodeIfPresent(fontWeight, forKey: .fontWeight)
        try container.encodeIfPresent(hyphens, forKey: .hyphens)
        try container.encodeIfPresent(blendImages, forKey: .blendImages)
        try container.encodeIfPresent(darkenImages, forKey: .darkenImages)
        try container.encodeIfPresent(invertImages, forKey: .invertImages)
        try container.encodeIfPresent(invertGaiji, forKey: .invertGaiji)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(letterSpacing, forKey: .letterSpacing)
        try container.encodeIfPresent(ligatures, forKey: .ligatures)
        try container.encodeIfPresent(lineHeight, forKey: .lineHeight)
        try container.encodeIfPresent(linkColor, forKey: .linkColor)
        try container.encodeIfPresent(maximalLineLength, forKey: .maximalLineLength)
        try container.encodeIfPresent(minimalLineLength, forKey: .minimalLineLength)
        try container.encodeIfPresent(noRuby, forKey: .noRuby)
        try container.encodeIfPresent(offsetFirstPage, forKey: .offsetFirstPage)
        try container.encodeIfPresent(optimalLineLength, forKey: .optimalLineLength)
        try container.encodeIfPresent(pageMargins, forKey: .pageMargins)
        try container.encodeIfPresent(paragraphIndent, forKey: .paragraphIndent)
        try container.encodeIfPresent(paragraphSpacing, forKey: .paragraphSpacing)
        try container.encodeIfPresent(readingProgression, forKey: .readingProgression)
        try container.encodeIfPresent(scroll, forKey: .scroll)
        try container.encodeIfPresent(spread, forKey: .spread)
        try container.encodeIfPresent(textAlign, forKey: .textAlign)
        try container.encodeIfPresent(textColor, forKey: .textColor)
        try container.encodeIfPresent(textNormalization, forKey: .textNormalization)
        try container.encodeIfPresent(verticalText, forKey: .verticalText)
        try container.encodeIfPresent(visitedColor, forKey: .visitedColor)
        try container.encodeIfPresent(wordSpacing, forKey: .wordSpacing)
    }
}

extension KeyedDecodingContainer {
    /// Decodes the value for `key`, or returns `nil` if it is missing or
    /// invalid.
    func decodeLeniently<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        try? decodeIfPresent(type, forKey: key)
    }
}
