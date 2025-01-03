//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public protocol HTMLFontFamilyDeclaration {
    /// Name of the font family.
    ///
    /// This will be the value of the `fontFamily` EPUB preference.
    var fontFamily: FontFamily { get }

    /// Specifies a list of alternative font families used as fallbacks when
    /// symbols are missing from `fontFamily`.
    var alternates: [FontFamily] { get }

    /// Injects this font family declaration in the given `html` document.
    ///
    /// Use `servingFile` to convert a file URL into an http one to make a local
    /// file available to the web views.
    func inject(in html: String, servingFile: (FileURL) throws -> HTTPURL) throws -> String
}

/// A type-erasing `HTMLFontFamilyDeclaration` object
public struct AnyHTMLFontFamilyDeclaration: HTMLFontFamilyDeclaration {
    private let _fontFamily: () -> FontFamily
    private let _alternates: () -> [FontFamily]
    private let _inject: (String, (FileURL) throws -> HTTPURL) throws -> String

    public var fontFamily: FontFamily { _fontFamily() }
    public var alternates: [FontFamily] { _alternates() }

    public init<T: HTMLFontFamilyDeclaration>(_ declaration: T) {
        _fontFamily = { declaration.fontFamily }
        _alternates = { declaration.alternates }
        _inject = { try declaration.inject(in: $0, servingFile: $1) }
    }

    public func inject(in html: String, servingFile: (FileURL) throws -> HTTPURL) throws -> String {
        try _inject(html, servingFile)
    }
}

public extension HTMLFontFamilyDeclaration {
    /// Returns a type-erased version of this object.
    func eraseToAnyHTMLFontFamilyDeclaration() -> AnyHTMLFontFamilyDeclaration {
        AnyHTMLFontFamilyDeclaration(self)
    }
}

/// A font family declaration.
public struct CSSFontFamilyDeclaration: HTMLFontFamilyDeclaration {
    public let fontFamily: FontFamily
    public let alternates: [FontFamily]

    /// Declarations for the individual font files for this font family.
    public var fontFaces: [CSSFontFace]

    public init(fontFamily: FontFamily, alternates: [FontFamily] = [], fontFaces: [CSSFontFace] = []) {
        self.fontFamily = fontFamily
        self.alternates = alternates
        self.fontFaces = fontFaces
    }

    public func inject(in html: String, servingFile: (FileURL) throws -> HTTPURL) throws -> String {
        var injections = try fontFaces.flatMap {
            try $0.injections(for: html, servingFile: servingFile)
        }

        let css = try fontFaces
            .map { try $0.css(for: fontFamily.rawValue, servingFile: servingFile) }
            .joined(separator: "\n")
        injections.append(.style(css))

        var html = html
        for injection in injections {
            html = try injection.inject(in: html)
        }
        return html
    }
}

/// Represents a single `@font-face` CSS rule.
public struct CSSFontFace {
    /// Represents an individual font file.
    ///
    /// `preload` indicates whether this source will be declared for preloading
    /// in the HTML using `<link rel="preload">`.
    private typealias Source = (file: FileURL, preload: Bool)

    public var style: CSSFontStyle?
    public var weight: CSSFontWeight?
    private var sources: [Source]

    public init(
        file: FileURL,
        preload: Bool = false,
        style: CSSFontStyle? = nil,
        weight: CSSFontWeight? = nil
    ) {
        self.style = style
        self.weight = weight
        sources = [(file, preload)]
    }

    /// Returns a new CSSFontFace after adding a linked source for this font
    /// face.
    ///
    /// - Parameter preload: Indicates whether this source will be declared for
    /// preloading in the HTML using `<link rel="preload">`.
    public func addingSource(file: FileURL, preload: Bool = false) -> Self {
        var copy = self
        copy.sources.append((file, preload))
        return copy
    }

    func injections(for html: String, servingFile: (FileURL) throws -> HTTPURL) throws -> [HTMLInjection] {
        try sources
            .filter(\.preload)
            .map { source in
                let file = try servingFile(source.file)
                return .link(href: file.string, rel: "preload", as: "font", crossOrigin: "")
            }
    }

    func css(for fontFamily: String, servingFile: (FileURL) throws -> HTTPURL) throws -> String {
        let urls = try sources.map { try servingFile($0.file) }
        var descriptors: [String: String] = [
            "font-family": "\"\(fontFamily)\"",
            "src": urls.map { "url(\"\($0.string)\")" }.joined(separator: ", "),
        ]

        if let style = style {
            descriptors["font-style"] = style.rawValue
        }
        switch weight {
        case nil:
            break
        case let .standard(weight):
            descriptors["font-weight"] = String(weight.rawValue)
        case let .variable(range):
            descriptors["font-weight"] = "\(range.lowerBound) \(range.upperBound)"
        }

        let descriptorsCSS = descriptors
            .map { key, value in "\(key): \(value);" }
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
public enum CSSFontWeight: Codable {
    case standard(CSSStandardFontWeight)
    case variable(ClosedRange<Int>)
}

/// Standard weights (or boldness) of a font.
///
/// See https://developer.mozilla.org/en-US/docs/Web/CSS/font-weight#common_weight_name_mapping
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
