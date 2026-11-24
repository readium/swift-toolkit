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
/// See https://github.com/readium/css/blob/develop/docs/CSS19-api.md#user-settings
struct CSSUserProperties: CSSProperties, Sendable {
    // View mode

    /// User view: paged or scrolled.
    var view: CSSView?

    // Pagination

    /// The number of columns (column-count) the user wants displayed.
    ///
    /// Readium CSS treats `0` as an error and renders a single column. To
    /// reset, set the property to `nil` instead.
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

    /// The weight (font-weight) of the text, from 1 to 1000.
    var fontWeight: Int?

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

    /// Hides the ruby (furigana) annotations when `true`. Only available with
    /// the CJK stylesheets.
    var noRuby: Bool?

    // WebKit patches

    /// Applies the patch for WebKit on iOS (iPhone).
    var iOSPatch: Bool?

    /// Applies the patch for WebKit on iPadOS, which requests the pages as
    /// desktop.
    var iPadOSPatch: Bool?

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
        fontWeight: Int? = nil,
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
        iOSPatch: Bool? = nil,
        iPadOSPatch: Bool? = nil
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
        self.fontWeight = fontWeight
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
        self.iOSPatch = iOSPatch
        self.iPadOSPatch = iPadOSPatch
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
        props.putCSS(name: "--USER__fontWeight", value: fontWeight)
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

        // WebKit patches
        props.putCSS(name: "--USER__iOSPatch", value: CSSFlag(name: "iOSPatch", isEnabled: iOSPatch))
        props.putCSS(name: "--USER__iPadOSPatch", value: CSSFlag(name: "iPadOSPatch", isEnabled: iPadOSPatch))

        return props
    }
}

/// Reading System properties.
///
/// Only the properties set by the navigator are declared.
///
/// See https://github.com/readium/css/blob/develop/docs/CSS19-api.md#reading-system-styles
struct CSSRSProperties: CSSProperties, Sendable {
    /// Disables the `overflow` rules of Readium CSS on `:root` and `body`.
    ///
    /// See https://github.com/readium/css/issues/183
    var noOverflow: Bool?

    init(noOverflow: Bool? = nil) {
        self.noOverflow = noOverflow
    }

    func cssProperties() -> [String: String?] {
        var props: [String: String?] = [:]
        props.putCSS(name: "--RS__disableOverflow", value: CSSFlag(name: "noOverflow", isEnabled: noOverflow))
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
