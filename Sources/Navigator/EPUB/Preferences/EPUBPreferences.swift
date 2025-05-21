//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Preferences for the `EPUBNavigatorViewController`.
public struct EPUBPreferences: ConfigurablePreferences {
    public static let empty: EPUBPreferences = .init()

    /// Default page background color.
    public var backgroundColor: Color?

    /// Number of reflowable columns to display (one-page view or two-page
    /// spread).
    public var columnCount: ColumnCount?

    /// Default typeface for the text.
    public var fontFamily: FontFamily?

    /// Base text font size.
    public var fontSize: Double?

    /// Default boldness for the text.
    public var fontWeight: Double?

    /// Enable hyphenation.
    public var hyphens: Bool?

    /// Filter applied to images in dark theme.
    public var imageFilter: ImageFilter?

    /// Language of the publication content.
    public var language: Language?

    /// Space between letters.
    public var letterSpacing: Double?

    /// Enable ligatures in Arabic.
    public var ligatures: Bool?

    /// Leading line height.
    public var lineHeight: Double?

    /// Factor applied to horizontal margins.
    public var pageMargins: Double?

    /// Text indentation for paragraphs.
    public var paragraphIndent: Double?

    /// Vertical margins for paragraphs.
    public var paragraphSpacing: Double?

    /// Indicates whether the original publisher styles should be observed.
    ///
    /// Many settings require this to be off.
    public var publisherStyles: Bool?

    /// Direction of the reading progression across resources.
    public var readingProgression: ReadingProgression?

    /// Indicates if the overflow of resources should be handled using
    /// scrolling instead of synthetic pagination.
    public var scroll: Bool?

    /// Indicates if the fixed-layout publication should be rendered with a
    /// synthetic spread (dual-page).
    public var spread: Spread?

    /// Page text alignment.
    public var textAlign: TextAlignment?

    /// Default page text color.
    public var textColor: Color?

    /// Normalize text styles to increase accessibility.
    public var textNormalization: Bool?

    /// Reader theme.
    public var theme: Theme?

    /// Scale applied to all element font sizes.
    public var typeScale: Double?

    /// Indicates whether the text should be laid out vertically.
    ///
    /// This is used for example with CJK languages. This setting is
    /// automatically derived from the language if no preference is given.
    public var verticalText: Bool?

    /// Space between words.
    public var wordSpacing: Double?

    public init(
        backgroundColor: Color? = nil,
        columnCount: ColumnCount? = nil,
        fontFamily: FontFamily? = nil,
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
        textColor: Color? = nil,
        textNormalization: Bool? = nil,
        theme: Theme? = nil,
        typeScale: Double? = nil,
        verticalText: Bool? = nil,
        wordSpacing: Double? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.columnCount = columnCount
        self.fontFamily = fontFamily
        self.fontSize = fontSize.map { max($0, 0) }
        self.fontWeight = fontWeight?.clamped(to: 0.0 ... 2.5)
        self.hyphens = hyphens
        self.imageFilter = imageFilter
        self.language = language
        self.letterSpacing = letterSpacing.map { max($0, 0) }
        self.ligatures = ligatures
        self.lineHeight = lineHeight
        self.pageMargins = pageMargins.map { max($0, 0) }
        self.paragraphIndent = paragraphIndent
        self.paragraphSpacing = paragraphSpacing.map { max($0, 0) }
        self.publisherStyles = publisherStyles
        self.readingProgression = readingProgression
        self.scroll = scroll
        self.spread = [nil, .never, .always].contains(spread) ? spread : nil
        self.textAlign = textAlign
        self.textColor = textColor
        self.textNormalization = textNormalization
        self.theme = theme
        self.typeScale = typeScale.map { max($0, 0) }
        self.verticalText = verticalText
        self.wordSpacing = wordSpacing.map { max($0, 0) }
    }

    public func merging(_ other: EPUBPreferences) -> EPUBPreferences {
        EPUBPreferences(
            backgroundColor: other.backgroundColor ?? backgroundColor,
            columnCount: other.columnCount ?? columnCount,
            fontFamily: other.fontFamily ?? fontFamily,
            fontSize: other.fontSize ?? fontSize,
            fontWeight: other.fontWeight ?? fontWeight,
            hyphens: other.hyphens ?? hyphens,
            imageFilter: other.imageFilter ?? imageFilter,
            language: other.language ?? language,
            letterSpacing: other.letterSpacing ?? letterSpacing,
            ligatures: other.ligatures ?? ligatures,
            lineHeight: other.lineHeight ?? lineHeight,
            pageMargins: other.pageMargins ?? pageMargins,
            paragraphIndent: other.paragraphIndent ?? paragraphIndent,
            paragraphSpacing: other.paragraphSpacing ?? paragraphSpacing,
            publisherStyles: other.publisherStyles ?? publisherStyles,
            readingProgression: other.readingProgression ?? readingProgression,
            scroll: other.scroll ?? scroll,
            spread: other.spread ?? spread,
            textAlign: other.textAlign ?? textAlign,
            textColor: other.textColor ?? textColor,
            textNormalization: other.textNormalization ?? textNormalization,
            theme: other.theme ?? theme,
            typeScale: other.typeScale ?? typeScale,
            verticalText: other.verticalText ?? verticalText,
            wordSpacing: other.wordSpacing ?? wordSpacing
        )
    }

    /// Returns a new `EPUBPreferences` with the publication-specific preferences
    /// removed.
    public func filterSharedPreferences() -> EPUBPreferences {
        var prefs = self
        prefs.language = nil
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
            readingProgression: readingProgression,
            spread: spread,
            verticalText: verticalText
        )
    }
}
