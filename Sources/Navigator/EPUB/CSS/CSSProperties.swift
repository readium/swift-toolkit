//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Object that can be converted to raw CSS.
public protocol CSSConvertible {
    func css() -> String?
}

/// Holds a set of Readium CSS properties applied together.
public protocol CSSProperties: CSSConvertible {
    func cssProperties() -> [String: String?]
}

public extension CSSProperties {
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
public struct CSSUserProperties: CSSProperties {
    // View mode

    /// User view: paged or scrolled.
    public var view: CSSView?

    // Pagination

    /// The number of columns (column-count) the user wants displayed (one-page view or two-page
    /// spread).
    ///
    /// To reset, change the value to auto.
    public var colCount: CSSColCount?

    /// A factor applied to horizontal margins (padding-left and padding-right) the user wants to
    /// set.
    ///
    /// Recommended values: a range from 0.5 to 2. Increments are left to implementers’ judgment.
    /// To reset, change the value to 1.
    public var pageMargins: Double?

    // Appearance

    /// This flag applies a reading mode (sepia or night).
    public var appearance: CSSAppearance?

    /// This will only apply in night mode to darken images and impact img.
    ///
    /// Requires: appearance = Appearance.Night
    public var darkenImages: Bool?

    /// This will only apply in night mode to invert images and impact img.
    ///
    /// Requires: appearance = Appearance.Night
    public var invertImages: Bool?

    /// The color for textual contents. It impacts all elements but headings and pre in the DOM.
    ///
    /// To reset, remove the CSS variable.
    public var textColor: CSSColor?

    /// The background-color for the whole screen. To reset, remove the CSS variable.
    public var backgroundColor: CSSColor?

    // Typography

    /// This flag is required to change the font-family user setting.
    public var fontOverride: Bool?

    /// The typeface (font-family) the user wants to read with. It impacts body, p, li, div, dt, dd
    /// and phrasing elements which don’t have a lang or xml:lang attribute.
    ///
    /// To reset, remove the required flag.
    /// Requires: fontOverride
    public var fontFamily: [String]?

    /// Increasing and decreasing the root font-size. It will serve as a reference for the cascade.
    ///
    /// To reset, remove the required flag.
    public var fontSize: CSSLength?

    // Advanced settings

    /// This flag is required to apply the font-size and/or advanced user settings.
    public var advancedSettings: Bool?

    /// The type scale the user wants to use for the publication. It impacts headings, p, li, div,
    /// pre, dd, small, sub, and sup.
    ///
    /// Recommended values: a range from 75% to 250%. Increments are left to implementers’ judgment.
    /// Requires: advancedSettings
    public var typeScale: Double?

    /// The alignment (text-align) the user prefers. It impacts body, li, and p which are not
    /// children of blockquote and figcaption.
    ///
    /// Requires: advancedSettings
    public var textAlign: CSSTextAlign?

    /// Increasing and decreasing leading (line-height). It impacts body, p, li and div.
    ///
    /// Recommended values: a range from 1 to 2. Increments are left to implementers’ judgment.
    /// Requires: advancedSettings
    public var lineHeight: CSSLineHeight?

    /// The vertical margins (margin-top and margin-bottom) for paragraphs.
    ///
    /// Recommended values: a range from 0 to 2rem. Increments are left to implementers’ judgment.
    /// Requires: advancedSettings = true
    public var paraSpacing: CSSLength?

    /// The text-indent for paragraphs.
    ///
    /// Recommended values: a range from 0 to 3rem. Increments are left to implementers’ judgment.
    /// Requires: advancedSettings
    public var paraIndent: CSSRemLength?

    /// Increasing space between words (word-spacing, related to a11y).
    ///
    /// Recommended values: a range from 0 to 1rem. Increments are left to implementers’ judgment.
    /// Requires: advancedSettings
    public var wordSpacing: CSSRemLength?

    /// Increasing space between letters (letter-spacing, related to a11y).
    ///
    /// Recommended values: a range from 0 to 0.5rem. Increments are left to implementers’
    /// judgment.
    /// Requires: advancedSettings
    public var letterSpacing: CSSRemLength?

    /// Enabling and disabling hyphenation. It impacts body, p, li, div and dd.
    ///
    /// Requires: advancedSettings
    public var bodyHyphens: CSSHyphens?

    /// Enabling and disabling ligatures in Arabic (related to a11y).
    ///
    /// Requires: advancedSettings
    public var ligatures: CSSLigatures?

    // Accessibility

    /// It impacts font style, weight and variant, text decoration, super and subscripts.
    ///
    /// Requires: fontOverride
    public var a11yNormalize: Bool?

    // Additional overrides for extensions and adjustments.
    public var overrides: [String: String?]

    public init(
        view: CSSView? = nil,
        colCount: CSSColCount? = nil,
        pageMargins: Double? = nil,
        appearance: CSSAppearance? = nil,
        darkenImages: Bool? = nil,
        invertImages: Bool? = nil,
        textColor: CSSColor? = nil,
        backgroundColor: CSSColor? = nil,
        fontOverride: Bool? = nil,
        fontFamily: [String]? = nil,
        fontSize: CSSLength? = nil,
        advancedSettings: Bool? = nil,
        typeScale: Double? = nil,
        textAlign: CSSTextAlign? = nil,
        lineHeight: CSSLineHeight? = nil,
        paraSpacing: CSSLength? = nil,
        paraIndent: CSSRemLength? = nil,
        wordSpacing: CSSRemLength? = nil,
        letterSpacing: CSSRemLength? = nil,
        bodyHyphens: CSSHyphens? = nil,
        ligatures: CSSLigatures? = nil,
        a11yNormalize: Bool? = nil,
        overrides: [String: String?] = [:]
    ) {
        self.view = view
        self.colCount = colCount
        self.pageMargins = pageMargins
        self.appearance = appearance
        self.darkenImages = darkenImages
        self.invertImages = invertImages
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.fontOverride = fontOverride
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.advancedSettings = advancedSettings
        self.typeScale = typeScale
        self.textAlign = textAlign
        self.lineHeight = lineHeight
        self.paraSpacing = paraSpacing
        self.paraIndent = paraIndent
        self.wordSpacing = wordSpacing
        self.letterSpacing = letterSpacing
        self.bodyHyphens = bodyHyphens
        self.ligatures = ligatures
        self.a11yNormalize = a11yNormalize
        self.overrides = overrides
    }

    public func cssProperties() -> [String: String?] {
        var props: [String: String?] = [:]
        // View mode
        props.putCSS(name: "--USER__view", value: view)

        // Pagination
        props.putCSS(name: "--USER__colCount", value: colCount)
        props.putCSS(name: "--USER__pageMargins", value: pageMargins)

        // Appearance
        props.putCSS(name: "--USER__appearance", value: appearance)
        props.putCSS(name: "--USER__darkenImages", value: CSSFlag(name: "darken", isEnabled: darkenImages))
        props.putCSS(name: "--USER__invertImages", value: CSSFlag(name: "invert", isEnabled: invertImages))

        // Colors
        props.putCSS(name: "--USER__textColor", value: textColor)
        props.putCSS(name: "--USER__backgroundColor", value: backgroundColor)

        // Typography
        props.putCSS(name: "--USER__fontOverride", value: CSSFlag(name: "font", isEnabled: fontOverride))
        props.putCSS(name: "--USER__fontFamily", value: fontFamily)
        props.putCSS(name: "--USER__fontSize", value: fontSize)

        // Advanced settings
        props.putCSS(name: "--USER__advancedSettings", value: CSSFlag(name: "advanced", isEnabled: advancedSettings))
        props.putCSS(name: "--USER__typeScale", value: typeScale)
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

        props.merge(overrides, uniquingKeysWith: { _, n in n })
        return props
    }
}

/// Reading System properties.
///
/// See https://readium.org/readium-css/docs/CSS19-api.html#reading-system-styles
public struct CSSRSProperties: CSSProperties {
    // Pagination

    /// @param colWidth The optimal column’s width. It serves as a floor in our design.
    public var colWidth: CSSLength?

    /// @param colCount The optimal number of columns (depending on the columns’ width).
    public var colCount: CSSColCount?

    /// @param colGap The gap between columns. You must account for this gap when scrolling.
    public var colGap: CSSAbsoluteLength?

    /// @param pageGutter The horizontal page margins.
    public var pageGutter: CSSAbsoluteLength?

    // Vertical rhythm

    /// @param flowSpacing The default vertical margins for HTML5 flow content e.g. pre, figure,
    /// blockquote, etc.
    public var flowSpacing: CSSLength?

    /// @param paraSpacing The default vertical margins for paragraphs.
    public var paraSpacing: CSSLength?

    /// @param paraIndent The default text-indent for paragraphs.
    public var paraIndent: CSSLength?

    // Safeguards

    /// @param maxLineLength The optimal line-length. It must be set in rem in order to take :root’s
    /// font-size as a reference, whichever the body’s font-size might be.
    public var maxLineLength: CSSRemLength?

    /// @param maxMediaWidth The max-width for media elements i.e. img, svg, audio and video.
    public var maxMediaWidth: CSSLength?

    /// @param maxMediaHeight The max-height for media elements i.e. img, svg, audio and video.
    public var maxMediaHeight: CSSLength?

    /// @param boxSizingMedia The box model (box-sizing) you want to use for media elements.
    public var boxSizingMedia: CSSBoxSizing?

    /// @param boxSizingTable The box model (box-sizing) you want to use for tables.
    public var boxSizingTable: CSSBoxSizing?

    // Colors

    /// @param textColor The default color for body copy’s text.
    public var textColor: CSSColor?

    /// @param backgroundColor The default background-color for pages.
    public var backgroundColor: CSSColor?

    /// @param selectionTextColor The color for selected text.
    public var selectionTextColor: CSSColor?

    /// @param selectionBackgroundColor The background-color for selected text.
    public var selectionBackgroundColor: CSSColor?

    /// @param linkColor The default color for hyperlinks.
    public var linkColor: CSSColor?

    /// @param visitedColor The default color for visited hyperlinks.
    public var visitedColor: CSSColor?

    /// @param primaryColor An optional primary accentuation color you could use for headings or any
    /// other element of your choice.
    public var primaryColor: CSSColor?

    /// @param secondaryColor An optional secondary accentuation color you could use for any element
    /// of your choice.
    public var secondaryColor: CSSColor?

    // Typography

    /// @param typeScale The scale to be used for computing all elements’ font-size. Since those font
    /// sizes are computed dynamically, you can set a smaller type scale when the user sets one
    /// of the largest font sizes.
    public var typeScale: Double?

    /// @param baseFontFamily The default typeface for body copy in case the ebook doesn’t have one
    /// declared. Please note some languages have a specific font-stack (japanese, hindi, etc.)
    public var baseFontFamily: [String]?

    /// @param baseLineHeight The default line-height for body copy in case the ebook doesn’t have
    /// one declared.
    public var baseLineHeight: CSSLineHeight?

    // Default font-stacks

    /// @param oldStyleTf An old style serif font-stack relying on pre-installed fonts.
    public var oldStyleTf: [String]?

    /// @param modernTf A modern serif font-stack relying on pre-installed fonts.
    public var modernTf: [String]?

    /// @param sansTf A neutral sans-serif font-stack relying on pre-installed fonts.
    public var sansTf: [String]?

    /// @param humanistTf A humanist sans-serif font-stack relying on pre-installed fonts.
    public var humanistTf: [String]?

    /// @param monospaceTf A monospace font-stack relying on pre-installed fonts.
    public var monospaceTf: [String]?

    // Default font-stacks for Japanese publications

    /// @param serifJa A Mincho font-stack whose fonts with proportional latin characters are
    /// prioritized for horizontal writing.
    public var serifJa: [String]?

    /// @param sansSerifJa A Gothic font-stack whose fonts with proportional latin characters are
    /// prioritized for horizontal writing.
    public var sansSerifJa: [String]?

    /// @param serifJaV A Mincho font-stack whose fonts with fixed-width latin characters are
    /// prioritized for vertical writing.
    public var serifJaV: [String]?

    /// @param sansSerifJaV A Gothic font-stack whose fonts with fixed-width latin characters are
    /// prioritized for vertical writing.
    public var sansSerifJaV: [String]?

    // Default styles for unstyled publications

    /// @param compFontFamily The typeface for headings.
    /// The value can be another variable e.g. var(-RS__humanistTf).
    public var compFontFamily: [String]?

    /// @param codeFontFamily The typeface for code snippets.
    /// The value can be another variable e.g. var(-RS__monospaceTf).
    public var codeFontFamily: [String]?

    // Additional overrides for extensions and adjustments.
    public var overrides: [String: String?]

    public init(
        colWidth: CSSLength? = nil,
        colCount: CSSColCount? = nil,
        colGap: CSSAbsoluteLength? = nil,
        pageGutter: CSSAbsoluteLength? = nil,
        flowSpacing: CSSLength? = nil,
        paraSpacing: CSSLength? = nil,
        paraIndent: CSSLength? = nil,
        maxLineLength: CSSRemLength? = nil,
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
        self.colWidth = colWidth
        self.colCount = colCount
        self.colGap = colGap
        self.pageGutter = pageGutter
        self.flowSpacing = flowSpacing
        self.paraSpacing = paraSpacing
        self.paraIndent = paraIndent
        self.maxLineLength = maxLineLength
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

    public func cssProperties() -> [String: String?] {
        var props: [String: String?] = [:]

        // Pagination
        props.putCSS(name: "--RS__colWidth", value: colWidth)
        props.putCSS(name: "--RS__colCount", value: colCount)
        props.putCSS(name: "--RS__colGap", value: colGap)
        props.putCSS(name: "--RS__pageGutter", value: pageGutter)

        // Vertical rhythm
        props.putCSS(name: "--RS__flowSpacing", value: flowSpacing)
        props.putCSS(name: "--RS__paraSpacing", value: paraSpacing)
        props.putCSS(name: "--RS__paraIndent", value: paraIndent)

        // Safeguards
        props.putCSS(name: "--RS__maxLineLength", value: maxLineLength)
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

public enum CSSView: String, CSSConvertible {
    case paged = "readium-paged-on"
    case scroll = "readium-scroll-on"

    public func css() -> String? { rawValue }
}

public enum CSSColCount: String, CSSConvertible {
    case auto
    case one = "1"
    case two = "2"

    public func css() -> String? { rawValue }
}

public enum CSSAppearance: String, CSSConvertible {
    case night = "readium-night-on"
    case sepia = "readium-sepia-on"

    public func css() -> String? { rawValue }
}

public protocol CSSColor: CSSConvertible {}

public struct CSSRGBColor: CSSColor {
    let red: Int
    let green: Int
    let blue: Int

    public init(red: Int, green: Int, blue: Int) {
        precondition((0 ... 255).contains(red))
        precondition((0 ... 255).contains(green))
        precondition((0 ... 255).contains(blue))
        self.red = red
        self.green = green
        self.blue = blue
    }

    public func css() -> String? {
        "rgb(\(red), \(green), \(blue))"
    }
}

public struct CSSHexColor: CSSColor {
    let color: String

    public init(_ color: String) {
        self.color = color
    }

    public func css() -> String? { color }
}

public struct CSSIntColor: CSSColor {
    let color: Int

    public init(_ color: Int) {
        self.color = color
    }

    public func css() -> String? {
        String(format: "#%06X", 0xFFFFFF & color)
    }
}

public protocol CSSLength: CSSConvertible {}

public protocol CSSAbsoluteLength: CSSLength {}

/// Centimeters
public struct CSSCmLength: CSSAbsoluteLength {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public func css() -> String? { value.css(unit: "cm") }
}

/// Millimeters
public struct CSSMmLength: CSSAbsoluteLength {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public func css() -> String? { value.css(unit: "mm") }
}

/// Inches
public struct CSSInLength: CSSAbsoluteLength {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public func css() -> String? { value.css(unit: "in") }
}

/// Pixels
public struct CSSPxLength: CSSAbsoluteLength {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public func css() -> String? { value.css(unit: "px") }
}

/// Points
public struct CSSPtLength: CSSAbsoluteLength {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public func css() -> String? { value.css(unit: "pt") }
}

/// Picas
public struct CSSPcLength: CSSAbsoluteLength {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public func css() -> String? { value.css(unit: "pc") }
}

public protocol CSSRelativeLength: CSSLength {}

/// Relative to the font-size of the element.
public struct CSSEmLength: CSSRelativeLength {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public func css() -> String? { value.css(unit: "em") }
}

/// Relative to the width of the "0" (zero).
public struct CSSChLength: CSSRelativeLength {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public func css() -> String? { value.css(unit: "ch") }
}

/// Relative to font-size of the root element.
public struct CSSRemLength: CSSRelativeLength {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public func css() -> String? { value.css(unit: "rem") }
}

/// Relative to 1% of the width of the viewport.
public struct CSSVwLength: CSSRelativeLength {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public func css() -> String? { value.css(unit: "vw") }
}

/// Relative to 1% of the height of the viewport.
public struct CSSVhLength: CSSRelativeLength {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public func css() -> String? { value.css(unit: "vh") }
}

/// Relative to 1% of viewport's smaller dimension.
public struct CSSVMinLength: CSSRelativeLength {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public func css() -> String? { value.css(unit: "vmin") }
}

/// Relative to 1% of viewport's larger dimension.
public struct CSSVMaxLength: CSSRelativeLength {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public func css() -> String? { value.css(unit: "vmax") }
}

/// Relative to the parent element.
public struct CSSPercentLength: CSSRelativeLength {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public func css() -> String? { (value * 100).css(unit: "%") }
}

public enum CSSTextAlign: String, CSSConvertible {
    case start
    case left
    case right
    case justify

    public func css() -> String? { rawValue }
}

/// Line height supports unitless numbers.
public enum CSSLineHeight: CSSConvertible {
    case length(CSSLength)
    case unitless(Double)

    public func css() -> String? {
        switch self {
        case let .length(length):
            return length.css()
        case let .unitless(value):
            return String(format: "%.5f", value)
        }
    }
}

public enum CSSHyphens: String, CSSConvertible {
    case none
    case auto

    public func css() -> String? { rawValue }
}

public enum CSSLigatures: String, CSSConvertible {
    case none
    case common = "common-ligatures"

    public func css() -> String? { rawValue }
}

public enum CSSBoxSizing: String, CSSConvertible {
    case contentBox = "content-box"
    case borderBox = "border-box"

    public func css() -> String? { rawValue }
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

    mutating func putCSS(name: String, value: Double?) {
        let css = value.map { String(format: "%.5f", $0) }
        self[name] = css
    }

    mutating func putCSS(name: String, value: [String]?) {
        let css = value?.compactMap { $0.css() }.joined(separator: ", ")
        self[name] = css
    }
}
