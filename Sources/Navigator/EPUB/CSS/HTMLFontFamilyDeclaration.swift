//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

public protocol HTMLFontFamilyDeclaration {

    /// Name of the font family.
    ///
    /// This will be the value of the `fontFamily` EPUB preference.
    var fontFamily: String { get }

    /// Specifies a list of alternative font families used as fallbacks when
    /// symbols are missing from `fontFamily`.
    var alternates: [String] { get }

    /// Injects this font family declaration in the given `html` document.
    func inject(in html: String) throws -> String
}

/// A type-erasing `HTMLFontFamilyDeclaration` object
public struct AnyHTMLFontFamilyDeclaration: HTMLFontFamilyDeclaration {

    private let _fontFamily: () -> String
    private let _alternates: () -> [String]
    private let _inject: (String) throws -> String

    public var fontFamily: String { _fontFamily() }
    public var alternates: [String] { _alternates() }

    public init<T: HTMLFontFamilyDeclaration>(_ declaration: T) {
        _fontFamily = { declaration.fontFamily }
        _alternates = { declaration.alternates }
        _inject = { try declaration.inject(in: $0) }
    }

    public func inject(in html: String) throws -> String {
        try _inject(html)
    }
}

extension HTMLFontFamilyDeclaration {
    /// Returns a type-erased version of this object.
    public func eraseToAnyHTMLFontFamilyDeclaration() -> AnyHTMLFontFamilyDeclaration {
        AnyHTMLFontFamilyDeclaration(self)
    }
}

/// A font family declaration.
public struct CSSFontFamilyDeclaration: HTMLFontFamilyDeclaration, HTMLInjectable {

    public let fontFamily: String
    public let alternates: [String]

    /// Declarations for the individual font files for this font family.
    public var fontFaces: [CSSFontFace]

    public init(fontFamily: String, alternates: [String] = [], fontFaces: [CSSFontFace] = []) {
        self.fontFamily = fontFamily
        self.alternates = alternates
        self.fontFaces = fontFaces
    }

    public func inject(in html: String) throws -> String {
        try (self as HTMLInjectable).inject(in: html)
    }

    func injections(for html: String) throws -> [HTMLInjection] {
        var injections = try fontFaces.flatMap { try $0.injections(for: html) }
        let css = fontFaces
            .map { $0.css(for: fontFamily) }
            .joined(separator: "\n")
        injections.append(.style(css))
        return injections
    }
}

/// Represents a single `@font-face` CSS rule.
public struct CSSFontFace: HTMLInjectable {

    /// Represents an individual font file.
    ///
    /// `preload` indicates whether this source will be declared for preloading
    /// in the HTML using `<link rel="preload">`.
    private typealias Source = (href: String, preload: Bool)

    public var style: CSSFontStyle?
    public var weight: CSSFontWeight?
    private var sources: [Source]

    public init(
        style: CSSFontStyle? = nil,
        weight: CSSFontWeight? = nil
    ) {
        self.style = style
        self.weight = weight
        self.sources = []
    }

    /// Returns a new CSSFontFace after adding a linked source for this font
    /// face.
    ///
    /// - Parameter preload: Indicates whether this source will be declared for
    /// preloading in the HTML using `<link rel="preload">`.
    func addingSource(href: String, preload: Bool = false) -> Self {
        var copy = self
        copy.sources.append((href, preload))
        return copy
    }

    func injections(for html: String) throws -> [HTMLInjection] {
        sources
            .filter { $0.preload }
            .map { .link(href: $0.href, rel: "preload", as: "font", crossOrigin: "") }
    }
    
    func css(for fontFamily: String) -> String {
        var descriptors: [String: String] = [
            "font-family": "\"\(fontFamily)\"",
            "src": sources.map { "url(\"\($0.href)\")" }.joined(separator: ", ")
        ]

        if let style = style {
            descriptors["font-style"] = style.rawValue
        }
        switch weight {
        case nil:
            break
        case .standard(let weight):
            descriptors["font-weight"] = String(weight.rawValue)
        case .variable(let range):
            descriptors["font-weight"] = "\(range.lowerBound) \(range.upperBound)"
        }

        let descriptorsCSS = descriptors
            .map { (key, value) in "\(key): \(value);" }
            .joined(separator: " ")

        return "@font-face { \(descriptorsCSS) }"
    }
}

/// Styles that a font can be styled with.
public enum CSSFontStyle: String, Codable {
    case normal
    case italic
}

/// Weight (or boldness) of a font.

/// See https://developer.mozilla.org/en-US/docs/Web/CSS/@font-face/font-weight#common_weight_name_mapping
public enum CSSFontWeight: Codable {
    case standard(CSSStandardFontWeight)
    case variable(ClosedRange<Int>)
}

/// Standard weights (or boldness) of a font.

/// See https://developer.mozilla.org/en-US/docs/Web/CSS/@font-face/font-weight#common_weight_name_mapping
public enum CSSStandardFontWeight: Int, Codable {
    case thin = 100
    case extraLight = 200
    case light = 300
    case normal = 400
    case medium = 500
    case semiBold = 600
    case bold = 700
    case extraBold = 800
    case black = 900
}
