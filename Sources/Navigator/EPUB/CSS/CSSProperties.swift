//
//  Copyright 2022 Readium Foundation. All rights reserved.
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
            .map { key, value in "\(key): \(value)"}
            .joined(separator: ";\n") + ";\n"
    }
}

/// User settings properties.
///
/// See https://readium.org/readium-css/docs/CSS19-api.html#user-settings
public struct CSSUserProperties: CSSProperties {

    // View mode

    /// User view: paged or scrolled.
    public let view: CSSView?


    // Pagination

    /// The number of columns (column-count) the user wants displayed (one-page view or two-page
    /// spread).
    ///
    /// To reset, change the value to auto.
    public let colCount: CSSColCount?

    /// A factor applied to horizontal margins (padding-left and padding-right) the user wants to
    /// set.
    ///
    /// Recommended values: a range from 0.5 to 2. Increments are left to implementers’ judgment.
    /// To reset, change the value to 1.
    public let pageMargins: Double?


    // Appearance

    /// This flag applies a reading mode (sepia or night).
    public let appearance: CSSAppearance?

    /// This will only apply in night mode to darken images and impact img.
    ///
    /// Requires: appearance = Appearance.Night
    public let darkenImages: Bool?

    /// This will only apply in night mode to invert images and impact img.
    ///
    /// Requires: appearance = Appearance.Night
    public let invertImages: Bool?

    /// The color for textual contents. It impacts all elements but headings and pre in the DOM.
    ///
    /// To reset, remove the CSS variable.
    public let textColor: CSSColor?

    /// The background-color for the whole screen. To reset, remove the CSS variable.
    public let backgroundColor: CSSColor?


    // Typography

    /// This flag is required to change the font-family user setting.
    public let fontOverride: Bool?

    /// The typeface (font-family) the user wants to read with. It impacts body, p, li, div, dt, dd
    /// and phrasing elements which don’t have a lang or xml:lang attribute.
    ///
    /// To reset, remove the required flag.
    /// Requires: fontOverride
    public let fontFamily: [String]?

    /// Increasing and decreasing the root font-size. It will serve as a reference for the cascade.
    ///
    /// To reset, remove the required flag.
    public let fontSize: CSSLength?


    // Advanced settings

    /// This flag is required to apply the font-size and/or advanced user settings.
    public let advancedSettings: Bool?

    /// The type scale the user wants to use for the publication. It impacts headings, p, li, div,
    /// pre, dd, small, sub, and sup.
    ///
    /// Recommended values: a range from 75% to 250%. Increments are left to implementers’ judgment.
    /// Requires: advancedSettings
    public let typeScale: Double?

    /// The alignment (text-align) the user prefers. It impacts body, li, and p which are not
    /// children of blockquote and figcaption.
    ///
    /// Requires: advancedSettings
    public let textAlign: CSSTextAlign?

    /// Increasing and decreasing leading (line-height). It impacts body, p, li and div.
    ///
    /// Recommended values: a range from 1 to 2. Increments are left to implementers’ judgment.
    /// Requires: advancedSettings
    public let lineHeight: CSSLineHeight?

    /// The vertical margins (margin-top and margin-bottom) for paragraphs.
    ///
    /// Recommended values: a range from 0 to 2rem. Increments are left to implementers’ judgment.
    /// Requires: advancedSettings = true
    public let paraSpacing: CSSLength?

    /// The text-indent for paragraphs.
    ///
    /// Recommended values: a range from 0 to 3rem. Increments are left to implementers’ judgment.
    /// Requires: advancedSettings
    public let paraIndent: CSSRemLength?

    /// Increasing space between words (word-spacing, related to a11y).
    ///
    /// Recommended values: a range from 0 to 1rem. Increments are left to implementers’ judgment.
    /// Requires: advancedSettings
    public let wordSpacing: CSSRemLength?

    /// Increasing space between letters (letter-spacing, related to a11y).
    ///
    /// Recommended values: a range from 0 to 0.5rem. Increments are left to implementers’
    /// judgment.
    /// Requires: advancedSettings
    public let letterSpacing: CSSRemLength?

    /// Enabling and disabling hyphenation. It impacts body, p, li, div and dd.
    ///
    /// Requires: advancedSettings
    public let bodyHyphens: CSSHyphens?

    /// Enabling and disabling ligatures in Arabic (related to a11y).
    ///
    /// Requires: advancedSettings
    public let ligatures: CSSLigatures?


    // Accessibility

    /// It impacts font style, weight and variant, text decoration, super and subscripts.
    ///
    /// Requires: fontOverride
    public let a11yNormalize: Bool?

    // Additional overrides for extensions and adjustments.
    public let overrides: [String: String?]

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

public enum CSSView: String, CSSConvertible {
    case paged = "readium-paged-on"
    case scroll = "readium-scroll-on"

    public func css() -> String? { rawValue }
}

public enum CSSColCount: String, CSSConvertible {
    case auto = "auto"
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

public class CSSRGBColor: CSSColor {
    let red: Int
    let green: Int
    let blue: Int

    public init(red: Int, green: Int, blue: Int) {
        precondition((0...255).contains(red))
        precondition((0...255).contains(green))
        precondition((0...255).contains(blue))
        self.red = red
        self.green = green
        self.blue = blue
    }

    public func css() -> String? {
        "rgb(\(red), \(green), \(blue)"
    }
}

public class CSSHexColor: CSSColor {
    let color: String

    public init(_ color: String) {
        self.color = color
    }

    public func css() -> String? { color }
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
        case .length(let length):
            return length.css()
        case .unitless(let value):
            return doubleCSSFormatter.string(from: value as NSNumber)
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
        (doubleCSSFormatter.string(from: self as NSNumber) ?? "0") + unit
    }
}

private extension String {
    func css() -> String? {
        "\"" + replacingOccurrences(of: "\"", with: "\\\"") + "\""
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
        let css = value.flatMap { doubleCSSFormatter.string(from: $0 as NSNumber) }
        self[name] = css
    }

    mutating func putCSS(name: String, value: [String]?) {
        let css = value?.compactMap { $0.css() }.joined(separator: ", ")
        self[name] = css
    }
}

private let doubleCSSFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 5
    return f
}()
