//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public enum HTMLFontFamilyError: Error {
    case fontNotServed(FileURL)
}

public protocol HTMLFontFamilyDeclaration: Sendable {
    /// Name of the font family.
    ///
    /// This will be the value of the `fontFamily` EPUB preference.
    var fontFamily: FontFamily { get }

    /// Specifies a list of alternative font families used as fallbacks when
    /// symbols are missing from `fontFamily`.
    var alternates: [FontFamily] { get }

    /// List of local font files that must be served and made accessible to web
    /// content before calling `inject(in:servedFiles:)`.
    ///
    /// This is optional and only needed when the implementation injects local
    /// font files. Return an empty array if no local files need to be served.
    var fontFiles: [FileURL] { get }

    /// Injects this font family declaration in the given `html` document.
    ///
    /// Use `servedFiles` to look up the web-accessible URL for a given
    /// `fontFiles` URL.
    func inject(in html: String, servedFiles: [FileURL: any AbsoluteURL]) throws -> String
}

public extension HTMLFontFamilyDeclaration {
    var fontFiles: [FileURL] {
        []
    }
}

/// A type-erasing `HTMLFontFamilyDeclaration` object
public struct AnyHTMLFontFamilyDeclaration: HTMLFontFamilyDeclaration, Sendable {
    private let _fontFamily: @Sendable () -> FontFamily
    private let _alternates: @Sendable () -> [FontFamily]
    private let _fontFiles: @Sendable () -> [FileURL]
    private let _inject: @Sendable (String, [FileURL: any AbsoluteURL]) throws -> String

    public var fontFamily: FontFamily {
        _fontFamily()
    }

    public var alternates: [FontFamily] {
        _alternates()
    }

    public var fontFiles: [FileURL] {
        _fontFiles()
    }

    public init<T: HTMLFontFamilyDeclaration>(_ declaration: T) {
        _fontFamily = { declaration.fontFamily }
        _alternates = { declaration.alternates }
        _fontFiles = { declaration.fontFiles }
        _inject = { try declaration.inject(in: $0, servedFiles: $1) }
    }

    public func inject(in html: String, servedFiles: [FileURL: any AbsoluteURL]) throws -> String {
        try _inject(html, servedFiles)
    }
}

public extension HTMLFontFamilyDeclaration {
    /// Returns a type-erased version of this object.
    func eraseToAnyHTMLFontFamilyDeclaration() -> AnyHTMLFontFamilyDeclaration {
        AnyHTMLFontFamilyDeclaration(self)
    }
}

/// A font family declaration.
public struct CSSFontFamilyDeclaration: HTMLFontFamilyDeclaration, Sendable {
    public let fontFamily: FontFamily
    public let alternates: [FontFamily]

    /// Declarations for the individual font files for this font family.
    public var fontFaces: [CSSFontFace]

    public var fontFiles: [FileURL] {
        fontFaces.flatMap(\.fontFiles)
    }

    public init(fontFamily: FontFamily, alternates: [FontFamily] = [], fontFaces: [CSSFontFace] = []) {
        self.fontFamily = fontFamily
        self.alternates = alternates
        self.fontFaces = fontFaces
    }

    public func inject(in html: String, servedFiles: [FileURL: any AbsoluteURL]) throws -> String {
        var injections = try fontFaces.flatMap {
            try $0.injections(for: html, servedFiles: servedFiles)
        }

        let css = try fontFaces
            .map { try $0.css(for: fontFamily.rawValue, servedFiles: servedFiles) }
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
public struct CSSFontFace: Sendable {
    /// Represents an individual font file.
    ///
    /// `preload` indicates whether this source will be declared for preloading
    /// in the HTML using `<link rel="preload">`.
    private typealias Source = (file: FileURL, preload: Bool)

    public var style: CSSFontStyle?
    public var weight: CSSFontWeight?
    private var sources: [Source]

    public var fontFiles: [FileURL] {
        sources.map(\.file)
    }

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
    /// - Parameters:
    ///   - file: The URL to the font file to be added as a source.
    ///   - preload: Indicates whether this source will be declared for
    ///     preloading in the HTML using `<link rel="preload">`.
    public func addingSource(file: FileURL, preload: Bool = false) -> Self {
        var copy = self
        copy.sources.append((file, preload))
        return copy
    }

    func injections(for html: String, servedFiles: [FileURL: any AbsoluteURL]) throws -> [HTMLInjection] {
        try sources
            .filter(\.preload)
            .map { source in
                guard let file = servedFiles[source.file] else {
                    throw HTMLFontFamilyError.fontNotServed(source.file)
                }
                return .link(href: file.string, rel: "preload", as: "font", crossOrigin: "")
            }
    }

    func css(for fontFamily: String, servedFiles: [FileURL: any AbsoluteURL]) throws -> String {
        let urls = try sources.map { source in
            guard let url = servedFiles[source.file] else {
                throw HTMLFontFamilyError.fontNotServed(source.file)
            }
            return url
        }
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
public enum CSSFontStyle: String, Codable, Sendable {
    case normal
    case italic
}

/// Weight (or boldness) of a font.
public enum CSSFontWeight: Codable, Sendable {
    case standard(CSSStandardFontWeight)
    case variable(ClosedRange<Int>)
}

/// Standard weights (or boldness) of a font.
///
/// See https://developer.mozilla.org/en-US/docs/Web/CSS/font-weight#common_weight_name_mapping
public enum CSSStandardFontWeight: Int, Codable, Sendable {
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

extension WebViewServer {
    /// Serves the font files for the given font family declarations and returns
    /// a mapping from each font file URL to its web-accessible URL.
    func serve(
        _ fontFamilyDeclarations: [AnyHTMLFontFamilyDeclaration]
    ) -> [FileURL: any AbsoluteURL] {
        var servedFonts: [FileURL: AbsoluteURL] = [:]
        for ff in fontFamilyDeclarations {
            for file in ff.fontFiles {
                if servedFonts[file] == nil {
                    let name = file.lastPathSegment ?? UUID().uuidString
                    servedFonts[file] = serve(file: file, at: "assets/fonts/\(name)")
                }
            }
        }

        return servedFonts
    }
}
