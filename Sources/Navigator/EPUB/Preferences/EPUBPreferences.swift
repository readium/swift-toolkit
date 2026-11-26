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

    /// Blends the images with the background color.
    public var blendImages: Bool?

    /// Number of reflowable columns to display (one-page view or two-page
    /// spread).
    ///
    /// When `nil`, the number of columns is chosen automatically depending on
    /// the viewport size. Values lower than `1` are ignored.
    public var columnCount: Int?

    /// Darkens images by the given percentage, from `0.0` to `1.0`.
    ///
    /// Accepted range: `0.0...1.0`, other values are clamped. Suggested step:
    /// `0.1`. When unset, a control can start from `0.0`.
    public var darkenImages: Double?

    /// Method for fitting the content of fixed-layout resources within the
    /// viewport.
    ///
    /// - `auto` or `page`: Fit entire page within viewport (default).
    /// - `width`: Fit page width, allow vertical scrolling if needed.
    public var fit: Fit?

    /// Default typeface for the text.
    public var fontFamily: FontFamily?

    /// Base text font size, as a factor of the default size.
    ///
    /// Suggested range: `0.1...5.0`, with a step of `0.1`.
    public var fontSize: Double?

    /// Default boldness for the text.
    ///
    /// Accepted range: `0.0...2.5`, other values are clamped. Suggested step:
    /// `0.25`. When unset, a control can start from `1.0`.
    public var fontWeight: Double?

    /// Width of the glyphs, for the fonts which support it (variable fonts
    /// with a `wdth` axis).
    ///
    /// Accepted range: `0.5...2.5`, other values are clamped. Suggested step:
    /// `0.1`. When unset, a control can start from `1.0`.
    public var fontWidth: Double?

    /// Enable hyphenation.
    ///
    /// When unset, Readium CSS hyphenates the text only when it is justified.
    public var hyphens: Bool?

    /// Inverts the colors of the gaiji images when `true`.
    public var invertGaiji: Bool?

    /// Inverts the colors of the images when `true`.
    public var invertImages: Bool?

    /// Language of the publication content.
    public var language: Language?

    /// Space between letters.
    ///
    /// Accepted range: `0.0...`, negative values are replaced with `0.0`.
    /// Suggested range: `0.0...1.0`, with a step of `0.1`. When unset, a
    /// control can start from `0.0`.
    public var letterSpacing: Double?

    /// Enable ligatures.
    ///
    /// When unset, a control can start from `true`.
    public var ligatures: Bool?

    /// Leading line height.
    ///
    /// Suggested range: `1.0...2.0`, with a step of `0.1`. When unset, a
    /// control can start from `1.5`.
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
    ///
    /// Suggested range: `0.5...2.0`, with a step of `0.1`.
    public var optimalLineLength: Double?

    /// Factor applied to the maximal line length of the reflowable resources.
    ///
    /// When `nil`, `EPUBDefaults.maximalLineLength` is used. When both are
    /// `nil`, the lines take all the available width. Values lower than or
    /// equal to `0` are ignored.
    ///
    /// Suggested range: `0.5...2.0`, with a step of `0.1`. When unset, a
    /// control can start from `1.0`.
    public var maximalLineLength: Double?

    /// Factor applied to the minimal line length of the reflowable resources,
    /// under which the number of columns is reduced.
    ///
    /// It is used only in paginated mode, when `columnCount` is greater than
    /// 1. When `nil` and without a default value, the requested number of
    /// columns is always displayed, unless the margins leave no room for the
    /// lines. Values lower than or equal to `0` are ignored.
    ///
    /// Suggested range: `0.5...2.0`, with a step of `0.1`. When unset, a
    /// control can start from `1.0`.
    public var minimalLineLength: Double?

    /// Hides the ruby (furigana) annotations when `true`.
    ///
    /// Only effective with reflowable publications using a CJK layout
    /// (horizontal or vertical).
    public var noRuby: Bool?

    /// Indicates whether the first page should be displayed alone and centered
    /// instead of alongside the second page.
    ///
    /// This is only effective if spreads are enabled. When `nil` and without
    /// a default value, it is chosen automatically from the publication
    /// metadata.
    public var offsetFirstPage: Bool?

    /// Factor applied to the minimal margins on each side of the lines (left
    /// and right, or top and bottom with vertical text).
    ///
    /// Accepted range: `0.0...`, negative values are replaced with `0.0`.
    /// Suggested range: `0.0...4.0`, with a step of `0.3`.
    public var pageMargins: Double?

    /// Text indentation for paragraphs.
    ///
    /// Suggested range: `0.0...3.0`, with a step of `0.2`. When unset, a
    /// control can start from `0.0`.
    public var paragraphIndent: Double?

    /// Vertical margins for paragraphs.
    ///
    /// Accepted range: `0.0...`, negative values are replaced with `0.0`.
    /// Suggested range: `0.0...2.0`, with a step of `0.1`. When unset, a
    /// control can start from `0.0`.
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
    ///
    /// When `nil` and without a default value, the text alignment of the
    /// publication is kept.
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
    ///
    /// Accepted range: `0.0...`, negative values are replaced with `0.0`.
    /// Suggested range: `0.0...1.0`, with a step of `0.1`. When unset, a
    /// control can start from `0.0`.
    public var wordSpacing: Double?

    public init(
        backgroundColor: Color? = nil,
        blendImages: Bool? = nil,
        columnCount: Int? = nil,
        darkenImages: Double? = nil,
        fit: Fit? = nil,
        fontFamily: FontFamily? = nil,
        fontSize: Double? = nil,
        fontWeight: Double? = nil,
        fontWidth: Double? = nil,
        hyphens: Bool? = nil,
        invertGaiji: Bool? = nil,
        invertImages: Bool? = nil,
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
        self.blendImages = blendImages
        self.columnCount = Self.validColumnCount(columnCount)
        self.darkenImages = darkenImages?.clamped(to: Self.imageFilterRange)
        self.fit = fit
        self.fontFamily = fontFamily
        self.fontSize = fontSize?.positiveOrNil
        self.fontWeight = fontWeight?.clamped(to: Self.fontWeightRange)
        self.fontWidth = fontWidth?.clamped(to: Self.fontWidthRange)
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
        self.optimalLineLength = optimalLineLength?.positiveOrNil
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
}

/// Limits of the preferences, shared with `EPUBDefaults` and `EPUBSettings`.
extension EPUBPreferences {
    static let fontWeightRange: ClosedRange<Double> = 0.0 ... 2.5
    static let fontWidthRange: ClosedRange<Double> = 0.5 ... 2.5
    static let imageFilterRange: ClosedRange<Double> = 0.0 ... 1.0

    /// Returns the `columnCount`, or `nil` if it is lower than 1.
    static func validColumnCount(_ value: Int?) -> Int? {
        value.takeIf { $0 >= 1 }
    }
}
