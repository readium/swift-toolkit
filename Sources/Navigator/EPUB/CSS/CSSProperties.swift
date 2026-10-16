//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Object that can be converted to raw CSS.
protocol CSSConvertible {
    func css() -> String?
}

/// Holds a set of Readium CSS properties applied together.
protocol CSSProperties: CSSConvertible {
    func cssProperties() -> [String: String?]
}

extension CSSProperties {
    func css() -> String? {
        let props = cssProperties()
            .compactMapValues { $0 }

        guard !props.isEmpty else {
            return nil
        }

        return props
            .sorted(by: { p1, p2 in p1.key < p2.key })
            .map { key, value in "\(key): \(value) !important;" }
            .joined(separator: "\n") + "\n"
    }
}

/// User settings properties.
///
/// See https://readium.org/readium-css/docs/CSS19-api.html#user-settings
struct CSSUserProperties: CSSProperties, Sendable {
    // View mode

    /// User view: paged or scrolled.
    var view: CSSView?

    // Pagination

    /// The number of columns (column-count) the user wants displayed.
    ///
    /// To reset, change the value to 0.
    var colCount: Int?

    /// The maximum line length.
    var lineLength: CSSLength?

    // Appearance

    /// Blends the images with the background color.
    var blendImages: Bool?

    /// This will apply a brightness filter with the value it's given.
    var darkenImages: Double?

    /// This will apply an invert filter with the value it's given.
    var invertImages: Double?

    /// This will apply an invert filter with the value it's given,
    /// only to img class="gaiji".
    var invertGaiji: Double?

    /// The color for textual contents. It impacts all elements but headings and pre in the DOM.
    ///
    /// To reset, remove the CSS variable.
    var textColor: CSSColor?

    /// The background-color for the whole screen. To reset, remove the CSS variable.
    var backgroundColor: CSSColor?

    /// The color for hyperlinks. To reset, remove the CSS variable.
    var linkColor: CSSColor?

    /// The color for visited hyperlinks. To reset, remove the CSS variable.
    var visitedColor: CSSColor?

    // Typography

    /// The typeface (font-family) the user wants to read with. It impacts body, p, li, div, dt, dd
    /// and phrasing elements which don’t have a lang or xml:lang attribute.
    var fontFamily: [String]?

    /// Increasing and decreasing the root font-size. It will serve as a reference for the cascade.
    var fontSize: CSSLength?

    /// The width (font-stretch) of the glyphs, for variable fonts with a
    /// width axis. It impacts body.
    var fontWidth: CSSPercentLength?

    /// The alignment (text-align) the user prefers. It impacts body, li, and p which are not
    /// children of blockquote and figcaption.
    var textAlign: CSSTextAlign?

    /// Increasing and decreasing leading (line-height). It impacts body, p, li and div.
    ///
    /// Recommended values: a range from 1 to 2. Increments are left to implementers’ judgment.
    var lineHeight: CSSLineHeight?

    /// The vertical margins (margin-top and margin-bottom) for paragraphs.
    ///
    /// Recommended values: a range from 0 to 2rem. Increments are left to implementers’ judgment.
    var paraSpacing: CSSLength?

    /// The text-indent for paragraphs.
    ///
    /// Recommended values: a range from 0 to 3rem. Increments are left to implementers’ judgment.
    var paraIndent: CSSRemLength?

    /// Increasing space between words (word-spacing, related to a11y).
    ///
    /// Recommended values: a range from 0 to 1rem. Increments are left to implementers’ judgment.
    var wordSpacing: CSSRemLength?

    /// Increasing space between letters (letter-spacing, related to a11y).
    ///
    /// Recommended values: a range from 0 to 0.5rem. Increments are left to implementers’
    /// judgment.
    var letterSpacing: CSSRemLength?

    /// Enabling and disabling hyphenation. It impacts body, p, li, div and dd.
    var bodyHyphens: CSSHyphens?

    /// Enabling and disabling ligatures (related to a11y).
    var ligatures: CSSLigatures?

    // Accessibility

    /// It impacts font style, weight and variant, text decoration, super and subscripts.
    var a11yNormalize: Bool?

    /// Hiding/disabling ruby (furigana) annotations.
    var noRuby: Bool?

    /// Additional overrides for extensions and adjustments.
    var overrides: [String: String?]

    init(
        view: CSSView? = nil,
        colCount: Int? = nil,
        lineLength: CSSLength? = nil,
        blendImages: Bool? = nil,
        darkenImages: Double? = nil,
        invertImages: Double? = nil,
        invertGaiji: Double? = nil,
        textColor: CSSColor? = nil,
        backgroundColor: CSSColor? = nil,
        linkColor: CSSColor? = nil,
        visitedColor: CSSColor? = nil,
        fontFamily: [String]? = nil,
        fontSize: CSSLength? = nil,
        fontWidth: CSSPercentLength? = nil,
        textAlign: CSSTextAlign? = nil,
        lineHeight: CSSLineHeight? = nil,
        paraSpacing: CSSLength? = nil,
        paraIndent: CSSRemLength? = nil,
        wordSpacing: CSSRemLength? = nil,
        letterSpacing: CSSRemLength? = nil,
        bodyHyphens: CSSHyphens? = nil,
        ligatures: CSSLigatures? = nil,
        a11yNormalize: Bool? = nil,
        noRuby: Bool? = nil,
        overrides: [String: String?] = [:]
    ) {
        self.view = view
        self.colCount = colCount
        self.lineLength = lineLength
        self.blendImages = blendImages
        self.darkenImages = darkenImages
        self.invertImages = invertImages
        self.invertGaiji = invertGaiji
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.linkColor = linkColor
        self.visitedColor = visitedColor
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.fontWidth = fontWidth
        self.textAlign = textAlign
        self.lineHeight = lineHeight
        self.paraSpacing = paraSpacing
        self.paraIndent = paraIndent
        self.wordSpacing = wordSpacing
        self.letterSpacing = letterSpacing
        self.bodyHyphens = bodyHyphens
        self.ligatures = ligatures
        self.a11yNormalize = a11yNormalize
        self.noRuby = noRuby
        self.overrides = overrides
    }

    func cssProperties() -> [String: String?] {
        var props: [String: String?] = [:]
        // View mode
        props.putCSS(name: "--USER__view", value: view)

        // Pagination
        props.putCSS(name: "--USER__colCount", value: colCount)
        props.putCSS(name: "--USER__lineLength", value: lineLength)

        // Appearance
        props.putCSS(name: "--USER__blendImages", value: CSSFlag(name: "blend", isEnabled: blendImages))
        props.putCSS(name: "--USER__darkenImages", value: darkenImages)
        props.putCSS(name: "--USER__invertImages", value: invertImages)
        props.putCSS(name: "--USER__invertGaiji", value: invertGaiji)

        // Colors
        props.putCSS(name: "--USER__textColor", value: textColor)
        props.putCSS(name: "--USER__backgroundColor", value: backgroundColor)
        props.putCSS(name: "--USER__linkColor", value: linkColor)
        props.putCSS(name: "--USER__visitedColor", value: visitedColor)

        // Typography
        props.putCSS(name: "--USER__fontFamily", value: fontFamily)
        props.putCSS(name: "--USER__fontSize", value: fontSize)
        props.putCSS(name: "--USER__fontWidth", value: fontWidth)
        props.putCSS(name: "--USER__textAlign", value: textAlign)
        props.putCSS(name: "--USER__lineHeight", value: lineHeight)
        props.putCSS(name: "--USER__paraSpacing", value: paraSpacing)
        props.putCSS(name: "--USER__paraIndent", value: paraIndent)
        props.putCSS(name: "--USER__wordSpacing", value: wordSpacing)
        props.putCSS(name: "--USER__letterSpacing", value: letterSpacing)
        props.putCSS(name: "--USER__bodyHyphens", value: bodyHyphens)
        props.putCSS(name: "--USER__ligatures", value: ligatures)

        // Accessibility
        props.putCSS(name: "--USER__a11yNormalize", value: CSSFlag(name: "a11y", isEnabled: a11yNormalize))
        props.putCSS(name: "--USER__noRuby", value: CSSFlag(name: "noRuby", isEnabled: noRuby))

        props.merge(overrides, uniquingKeysWith: { _, n in n })
        return props
    }
}

/// Reading System properties.
///
/// See https://readium.org/readium-css/docs/CSS19-api.html#reading-system-styles
struct CSSRSProperties: CSSProperties, Sendable {
    // Pagination

    /// @param viewportWidth The optimal viewport width.
    var viewportWidth: CSSLength?

    /// @param colWidth The optimal column’s width. It serves as a floor in our design.
    var colWidth: CSSLength?

    /// @param colCount The optimal number of columns (depending on the columns’ width).
    var colCount: Int?

    /// @param colGap The gap between columns. You must account for this gap when scrolling.
    var colGap: CSSAbsoluteLength?

    /// @param pageGutter The horizontal page margins.
    var pageGutter: CSSAbsoluteLength?

    /// @param scrollPaddingTop The default top padding for continuous scroll mode.
    var scrollPaddingTop: CSSLength?

    /// @param scrollPaddingBottom The default bottom padding for continuous scroll mode.
    var scrollPaddingBottom: CSSLength?

    /// @param scrollPaddingLeft The default left padding for continuous scroll mode.
    var scrollPaddingLeft: CSSLength?

    /// @param scrollPaddingRight The default right padding for continuous scroll mode.
    var scrollPaddingRight: CSSLength?

    // Vertical rhythm

    /// @param flowSpacing The default vertical margins for HTML5 flow content e.g. pre, figure,
    /// blockquote, etc.
    var flowSpacing: CSSLength?

    /// @param paraSpacing The default vertical margins for paragraphs.
    var paraSpacing: CSSLength?

    /// @param paraIndent The default text-indent for paragraphs.
    var paraIndent: CSSLength?

    // Safeguards

    /// @param defaultLineLength The optimal line-length. It must be set in rem in order to take :root’s
    /// font-size as a reference, whichever the body’s font-size might be.
    var defaultLineLength: CSSRemLength?

    /// @param maxMediaWidth The max-width for media elements i.e. img, svg, audio and video.
    var maxMediaWidth: CSSLength?

    /// @param maxMediaHeight The max-height for media elements i.e. img, svg, audio and video.
    var maxMediaHeight: CSSLength?

    /// @param boxSizingMedia The box model (box-sizing) you want to use for media elements.
    var boxSizingMedia: CSSBoxSizing?

    /// @param boxSizingTable The box model (box-sizing) you want to use for tables.
    var boxSizingTable: CSSBoxSizing?

    // Colors

    /// @param textColor The default color for body copy’s text.
    var textColor: CSSColor?

    /// @param backgroundColor The default background-color for pages.
    var backgroundColor: CSSColor?

    /// @param selectionTextColor The color for selected text.
    var selectionTextColor: CSSColor?

    /// @param selectionBackgroundColor The background-color for selected text.
    var selectionBackgroundColor: CSSColor?

    /// @param linkColor The default color for hyperlinks.
    var linkColor: CSSColor?

    /// @param visitedColor The default color for visited hyperlinks.
    var visitedColor: CSSColor?

    /// @param primaryColor An optional primary accentuation color you could use for headings or any
    /// other element of your choice.
    var primaryColor: CSSColor?

    /// @param secondaryColor An optional secondary accentuation color you could use for any element
    /// of your choice.
    var secondaryColor: CSSColor?

    // Typography

    /// @param typeScale The scale to be used for computing all elements’ font-size. Since those font
    /// sizes are computed dynamically, you can set a smaller type scale when the user sets one
    /// of the largest font sizes.
    var typeScale: Double?

    /// @param baseFontFamily The default typeface for body copy in case the ebook doesn’t have one
    /// declared. Please note some languages have a specific font-stack (japanese, hindi, etc.)
    var baseFontFamily: [String]?

    /// @param baseLineHeight The default line-height for body copy in case the ebook doesn’t have
    /// one declared.
    var baseLineHeight: CSSLineHeight?

    // Default font-stacks

    /// @param oldStyleTf An old style serif font-stack relying on pre-installed fonts.
    var oldStyleTf: [String]?

    /// @param modernTf A modern serif font-stack relying on pre-installed fonts.
    var modernTf: [String]?

    /// @param sansTf A neutral sans-serif font-stack relying on pre-installed fonts.
    var sansTf: [String]?

    /// @param humanistTf A humanist sans-serif font-stack relying on pre-installed fonts.
    var humanistTf: [String]?

    /// @param monospaceTf A monospace font-stack relying on pre-installed fonts.
    var monospaceTf: [String]?

    // Default font-stacks for Japanese publications

    /// @param serifJa A Mincho font-stack whose fonts with proportional latin characters are
    /// prioritized for horizontal writing.
    var serifJa: [String]?

    /// @param sansSerifJa A Gothic font-stack whose fonts with proportional latin characters are
    /// prioritized for horizontal writing.
    var sansSerifJa: [String]?

    /// @param serifJaV A Mincho font-stack whose fonts with fixed-width latin characters are
    /// prioritized for vertical writing.
    var serifJaV: [String]?

    /// @param sansSerifJaV A Gothic font-stack whose fonts with fixed-width latin characters are
    /// prioritized for vertical writing.
    var sansSerifJaV: [String]?

    // Default styles for unstyled publications

    /// @param compFontFamily The typeface for headings.
    /// The value can be another variable e.g. var(-RS__humanistTf).
    var compFontFamily: [String]?

    /// @param codeFontFamily The typeface for code snippets.
    /// The value can be another variable e.g. var(-RS__monospaceTf).
    var codeFontFamily: [String]?

    /// Additional overrides for extensions and adjustments.
    var overrides: [String: String?]

    init(
        viewportWidth: CSSLength? = nil,
        colWidth: CSSLength? = nil,
        colCount: Int? = nil,
        colGap: CSSAbsoluteLength? = nil,
        pageGutter: CSSAbsoluteLength? = nil,
        scrollPaddingTop: CSSLength? = nil,
        scrollPaddingBottom: CSSLength? = nil,
        scrollPaddingLeft: CSSLength? = nil,
        scrollPaddingRight: CSSLength? = nil,
        flowSpacing: CSSLength? = nil,
        paraSpacing: CSSLength? = nil,
        paraIndent: CSSLength? = nil,
        defaultLineLength: CSSRemLength? = nil,
        maxMediaWidth: CSSLength? = nil,
        maxMediaHeight: CSSLength? = nil,
        boxSizingMedia: CSSBoxSizing? = nil,
        boxSizingTable: CSSBoxSizing? = nil,
        textColor: CSSColor? = nil,
        backgroundColor: CSSColor? = nil,
        selectionTextColor: CSSColor? = nil,
        selectionBackgroundColor: CSSColor? = nil,
        linkColor: CSSColor? = nil,
        visitedColor: CSSColor? = nil,
        primaryColor: CSSColor? = nil,
        secondaryColor: CSSColor? = nil,
        typeScale: Double? = nil,
        baseFontFamily: [String]? = nil,
        baseLineHeight: CSSLineHeight? = nil,
        oldStyleTf: [String]? = nil,
        modernTf: [String]? = nil,
        sansTf: [String]? = nil,
        humanistTf: [String]? = nil,
        monospaceTf: [String]? = nil,
        serifJa: [String]? = nil,
        sansSerifJa: [String]? = nil,
        serifJaV: [String]? = nil,
        sansSerifJaV: [String]? = nil,
        compFontFamily: [String]? = nil,
        codeFontFamily: [String]? = nil,
        overrides: [String: String?] = [:]
    ) {
        self.viewportWidth = viewportWidth
        self.colWidth = colWidth
        self.colCount = colCount
        self.colGap = colGap
        self.pageGutter = pageGutter
        self.scrollPaddingTop = scrollPaddingTop
        self.scrollPaddingBottom = scrollPaddingBottom
        self.scrollPaddingLeft = scrollPaddingLeft
        self.scrollPaddingRight = scrollPaddingRight
        self.flowSpacing = flowSpacing
        self.paraSpacing = paraSpacing
        self.paraIndent = paraIndent
        self.defaultLineLength = defaultLineLength
        self.maxMediaWidth = maxMediaWidth
        self.maxMediaHeight = maxMediaHeight
        self.boxSizingMedia = boxSizingMedia
        self.boxSizingTable = boxSizingTable
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.selectionTextColor = selectionTextColor
        self.selectionBackgroundColor = selectionBackgroundColor
        self.linkColor = linkColor
        self.visitedColor = visitedColor
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.typeScale = typeScale
        self.baseFontFamily = baseFontFamily
        self.baseLineHeight = baseLineHeight
        self.oldStyleTf = oldStyleTf
        self.modernTf = modernTf
        self.sansTf = sansTf
        self.humanistTf = humanistTf
        self.monospaceTf = monospaceTf
        self.serifJa = serifJa
        self.sansSerifJa = sansSerifJa
        self.serifJaV = serifJaV
        self.sansSerifJaV = sansSerifJaV
        self.compFontFamily = compFontFamily
        self.codeFontFamily = codeFontFamily
        self.overrides = overrides
    }

    func cssProperties() -> [String: String?] {
        var props: [String: String?] = [:]

        // Pagination
        props.putCSS(name: "--RS__viewportWidth", value: viewportWidth)
        props.putCSS(name: "--RS__colWidth", value: colWidth)
        props.putCSS(name: "--RS__colCount", value: colCount)
        props.putCSS(name: "--RS__colGap", value: colGap)
        props.putCSS(name: "--RS__pageGutter", value: pageGutter)
        props.putCSS(name: "--RS__scrollPaddingTop", value: scrollPaddingTop)
        props.putCSS(name: "--RS__scrollPaddingBottom", value: scrollPaddingBottom)
        props.putCSS(name: "--RS__scrollPaddingLeft", value: scrollPaddingLeft)
        props.putCSS(name: "--RS__scrollPaddingRight", value: scrollPaddingRight)

        // Vertical rhythm
        props.putCSS(name: "--RS__flowSpacing", value: flowSpacing)
        props.putCSS(name: "--RS__paraSpacing", value: paraSpacing)
        props.putCSS(name: "--RS__paraIndent", value: paraIndent)

        // Safeguards
        props.putCSS(name: "--RS__defaultLineLength", value: defaultLineLength)
        props.putCSS(name: "--RS__maxMediaWidth", value: maxMediaWidth)
        props.putCSS(name: "--RS__maxMediaHeight", value: maxMediaHeight)
        props.putCSS(name: "--RS__boxSizingMedia", value: boxSizingMedia)
        props.putCSS(name: "--RS__boxSizingTable", value: boxSizingTable)

        // Colors
        props.putCSS(name: "--RS__textColor", value: textColor)
        props.putCSS(name: "--RS__backgroundColor", value: backgroundColor)
        props.putCSS(name: "--RS__selectionTextColor", value: selectionTextColor)
        props.putCSS(name: "--RS__selectionBackgroundColor", value: selectionBackgroundColor)
        props.putCSS(name: "--RS__linkColor", value: linkColor)
        props.putCSS(name: "--RS__visitedColor", value: visitedColor)
        props.putCSS(name: "--RS__primaryColor", value: primaryColor)
        props.putCSS(name: "--RS__secondaryColor", value: secondaryColor)

        // Typography
        props.putCSS(name: "--RS__typeScale", value: typeScale)
        props.putCSS(name: "--RS__baseFontFamily", value: baseFontFamily)
        props.putCSS(name: "--RS__baseLineHeight", value: baseLineHeight)

        // Default font-stacks
        props.putCSS(name: "--RS__oldStyleTf", value: oldStyleTf)
        props.putCSS(name: "--RS__modernTf", value: modernTf)
        props.putCSS(name: "--RS__sansTf", value: sansTf)
        props.putCSS(name: "--RS__humanistTf", value: humanistTf)
        props.putCSS(name: "--RS__monospaceTf", value: monospaceTf)

        // Default font-stacks for Japanese publications
        props.putCSS(name: "--RS__serif-ja", value: serifJa)
        props.putCSS(name: "--RS__sans-serif-ja", value: sansSerifJa)
        props.putCSS(name: "--RS__serif-ja-v", value: serifJaV)
        props.putCSS(name: "--RS__sans-serif-ja-v", value: sansSerifJaV)

        // Default styles for unstyled publications
        props.putCSS(name: "--RS__compFontFamily", value: compFontFamily)
        props.putCSS(name: "--RS__codeFontFamily", value: codeFontFamily)

        props.merge(overrides, uniquingKeysWith: { _, n in n })

        return props
    }
}

enum CSSView: String, CSSConvertible, Sendable {
    case paged = "readium-paged-on"
    case scroll = "readium-scroll-on"

    func css() -> String? {
        rawValue
    }
}

protocol CSSColor: CSSConvertible, Sendable {}

struct CSSRGBColor: CSSColor, Sendable {
    let red: Int
    let green: Int
    let blue: Int

    init(red: Int, green: Int, blue: Int) {
        precondition((0 ... 255).contains(red))
        precondition((0 ... 255).contains(green))
        precondition((0 ... 255).contains(blue))
        self.red = red
        self.green = green
        self.blue = blue
    }

    func css() -> String? {
        "rgb(\(red), \(green), \(blue))"
    }
}

struct CSSHexColor: CSSColor, Sendable {
    let color: String

    init(_ color: String) {
        self.color = color
    }

    func css() -> String? {
        color
    }
}

struct CSSIntColor: CSSColor, Sendable {
    let color: Int

    init(_ color: Int) {
        self.color = color
    }

    func css() -> String? {
        String(format: "#%06X", 0xFFFFFF & color)
    }
}

protocol CSSLength: CSSConvertible, Sendable {}

protocol CSSAbsoluteLength: CSSLength {}

/// Centimeters
struct CSSCmLength: CSSAbsoluteLength, Sendable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    func css() -> String? {
        value.css(unit: "cm")
    }
}

/// Millimeters
struct CSSMmLength: CSSAbsoluteLength, Sendable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    func css() -> String? {
        value.css(unit: "mm")
    }
}

/// Inches
struct CSSInLength: CSSAbsoluteLength, Sendable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    func css() -> String? {
        value.css(unit: "in")
    }
}

/// Pixels
struct CSSPxLength: CSSAbsoluteLength, Sendable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    func css() -> String? {
        value.css(unit: "px")
    }
}

/// Points
struct CSSPtLength: CSSAbsoluteLength, Sendable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    func css() -> String? {
        value.css(unit: "pt")
    }
}

/// Picas
struct CSSPcLength: CSSAbsoluteLength, Sendable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    func css() -> String? {
        value.css(unit: "pc")
    }
}

protocol CSSRelativeLength: CSSLength {}

/// Relative to the font-size of the element.
struct CSSEmLength: CSSRelativeLength, Sendable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    func css() -> String? {
        value.css(unit: "em")
    }
}

/// Relative to the width of the "0" (zero).
struct CSSChLength: CSSRelativeLength, Sendable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    func css() -> String? {
        value.css(unit: "ch")
    }
}

/// Relative to font-size of the root element.
struct CSSRemLength: CSSRelativeLength, Sendable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    func css() -> String? {
        value.css(unit: "rem")
    }
}

/// Relative to 1% of the width of the viewport.
struct CSSVwLength: CSSRelativeLength, Sendable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    func css() -> String? {
        value.css(unit: "vw")
    }
}

/// Relative to 1% of the height of the viewport.
struct CSSVhLength: CSSRelativeLength, Sendable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    func css() -> String? {
        value.css(unit: "vh")
    }
}

/// Relative to 1% of viewport's smaller dimension.
struct CSSVMinLength: CSSRelativeLength, Sendable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    func css() -> String? {
        value.css(unit: "vmin")
    }
}

/// Relative to 1% of viewport's larger dimension.
struct CSSVMaxLength: CSSRelativeLength, Sendable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    func css() -> String? {
        value.css(unit: "vmax")
    }
}

/// Relative to the parent element.
struct CSSPercentLength: CSSRelativeLength, Sendable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    func css() -> String? {
        (value * 100).css(unit: "%")
    }
}

enum CSSTextAlign: String, CSSConvertible, Sendable {
    case start
    case left
    case right
    case justify

    func css() -> String? {
        rawValue
    }
}

/// Line height supports unitless numbers.
enum CSSLineHeight: CSSConvertible, Sendable {
    case length(CSSLength)
    case unitless(Double)

    func css() -> String? {
        switch self {
        case let .length(length):
            return length.css()
        case let .unitless(value):
            return String(format: "%.5f", value)
        }
    }
}

enum CSSHyphens: String, CSSConvertible, Sendable {
    case none
    case auto

    func css() -> String? {
        rawValue
    }
}

enum CSSLigatures: String, CSSConvertible, Sendable {
    case none
    case common = "common-ligatures"

    func css() -> String? {
        rawValue
    }
}

enum CSSBoxSizing: String, CSSConvertible, Sendable {
    case contentBox = "content-box"
    case borderBox = "border-box"

    func css() -> String? {
        rawValue
    }
}

private extension Double {
    func css(unit: String) -> String {
        String(format: "%.5f", self) + unit
    }
}

private extension String {
    func css() -> String? {
        if contains("\"") || contains(" ") {
            return "\"" + replacingOccurrences(of: "\"", with: "\\\"") + "\""
        } else {
            return self
        }
    }
}

private struct CSSFlag: CSSConvertible {
    let name: String
    let isEnabled: Bool?

    func css() -> String? {
        if isEnabled == true {
            return "readium-\(name)-on"
        } else {
            return nil
        }
    }
}

private extension Dictionary where Key == String, Value == String? {
    mutating func putCSS(name: String, value: CSSConvertible?) {
        self[name] = value?.css()
    }

    mutating func putCSS(name: String, value: String?) {
        self[name] = value?.css()
    }

    mutating func putCSS(name: String, value: Int?) {
        let css = value.map { String(format: "%d", $0) }
        self[name] = css
    }

    mutating func putCSS(name: String, value: Double?) {
        let css = value.map { String(format: "%.5f", $0) }
        self[name] = css
    }

    mutating func putCSS(name: String, value: [String]?) {
        let css = value?.compactMap { $0.css() }.joined(separator: ", ")
        self[name] = css
    }
}
