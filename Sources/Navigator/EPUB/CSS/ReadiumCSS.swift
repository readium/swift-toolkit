//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumShared
import SwiftSoup

struct ReadiumCSS {
    var layout: CSSLayout = .init()
    var rsProperties: CSSRSProperties = .init()
    var userProperties: CSSUserProperties = .init()

    /// Base URL of the Readium CSS assets.
    var baseURL: HTTPURL

    var fontFamilyDeclarations: [AnyHTMLFontFamilyDeclaration] = []
}

extension ReadiumCSS {
    mutating func update(with settings: EPUBSettings) {
        layout = settings.cssLayout
        userProperties = CSSUserProperties(
            view: settings.scroll ? .scroll : .paged,
            colCount: {
                switch settings.columnCount {
                case .auto: return .auto
                case .one: return .one
                case .two: return .two
                }
            }(),
            pageMargins: settings.pageMargins,
            appearance: {
                switch settings.theme {
                case .light: return nil
                case .dark: return .night
                case .sepia: return .sepia
                }
            }(),
            darkenImages: settings.imageFilter == .darken,
            invertImages: settings.imageFilter == .invert,
            textColor: settings.textColor.map { CSSIntColor($0.rawValue) },
            backgroundColor: settings.backgroundColor.map { CSSIntColor($0.rawValue) },
            fontOverride: settings.fontFamily != nil || settings.textNormalization,
            fontFamily: settings.fontFamily.map(resolveFontStack),
            fontSize: CSSPercentLength(settings.fontSize),
            advancedSettings: !settings.publisherStyles,
            typeScale: settings.typeScale,
            textAlign: {
                switch settings.textAlign {
                case .justify: return .justify
                case .left: return .left
                case .right: return .right
                case .start, .center, .end: return .start
                default: return nil
                }
            }(),
            lineHeight: settings.lineHeight.map { .unitless($0) },
            paraSpacing: settings.paragraphSpacing.map { CSSRemLength($0) },
            paraIndent: settings.paragraphIndent.map { CSSRemLength($0) },
            wordSpacing: settings.wordSpacing.map { CSSRemLength($0) },
            letterSpacing: settings.letterSpacing.map { CSSRemLength($0 / 2) },
            bodyHyphens: settings.hyphens.map { $0 ? .auto : .none },
            ligatures: settings.ligatures.map { $0 ? .common : .none },
            a11yNormalize: settings.textNormalization,
            overrides: [
                "font-weight": settings.fontWeight
                    .map { String(format: "%.0f", (Double(CSSStandardFontWeight.normal.rawValue) * $0).clamped(to: 1 ... 1000)) }
                    ?? "",
            ]
        )
    }

    func resolveFontStack(of fontFamily: FontFamily) -> [String] {
        var fonts: [String] = [fontFamily.rawValue]

        let alternates = fontFamilyDeclarations
            .first { $0.fontFamily == fontFamily }?
            .alternates ?? []

        fonts.append(contentsOf: alternates.flatMap(resolveFontStack))

        return fonts
    }
}

extension ReadiumCSS: HTMLInjectable {
    func willInject(in html: String) -> String {
        // Removes any dir attributes in html/body.
        let range = NSRange(html.startIndex..., in: html)
        return dirRegex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "$1")
    }

    /// https://github.com/readium/readium-css/blob/develop/docs/CSS06-stylesheets_order.md
    func injections(for html: String) throws -> [HTMLInjection] {
        let document = try parse(html)

        var inj: [HTMLInjection] = []
        inj.append(.meta(name: "viewport", content: "width=device-width, height=device-height, initial-scale=1.0"))
        inj.append(contentsOf: styleInjections(for: html))
        inj.append(cssPropertiesInjection())
        inj.append(contentsOf: dirInjection())
        try inj.append(contentsOf: langInjections(for: document))
        return inj
    }

    /// Injects the Readium CSS stylesheets and font face declarations.
    private func styleInjections(for html: String) -> [HTMLInjection] {
        var inj: [HTMLInjection] = []

        let hasStyles = hasStyles(html)
        var stylesheetsFolder = baseURL
        if let folder = layout.stylesheets.folder {
            stylesheetsFolder = stylesheetsFolder.appendingPath(folder, isDirectory: true)
        }

        inj.append(.stylesheetLink(
            href: stylesheetsFolder.appendingPath("ReadiumCSS-before.css", isDirectory: false).string,
            prepend: true
        ))
        if !hasStyles {
            inj.append(.stylesheetLink(href: stylesheetsFolder.appendingPath("ReadiumCSS-default.css", isDirectory: false).string))
        }
        inj.append(.stylesheetLink(href: stylesheetsFolder.appendingPath("ReadiumCSS-after.css", isDirectory: false).string))

        // Fix Readium CSS issue with the positioning of <audio> elements.
        // https://github.com/readium/readium-css/issues/94
        // https://github.com/readium/r2-navigator-kotlin/issues/193
        inj.append(.style("audio[controls] { width: revert; height: revert; }"))

        return inj
    }

    /// Returns whether the given `html` has any CSS styles.
    ///
    /// https://github.com/readium/readium-css/blob/develop/docs/CSS06-stylesheets_order.md#append-if-there-is-no-authors-styles
    private func hasStyles(_ html: String) -> Bool {
        html.localizedCaseInsensitiveContains("<link ")
            || html.localizedCaseInsensitiveContains(" style=")
            || html.localizedCaseInsensitiveContains("</style>")
    }

    /// Injects the current Readium CSS properties inline in `html`.
    ///
    /// We inject them instead of using JavaScript to make sure they are taken into account during
    /// the first layout pass.
    private func cssPropertiesInjection() -> HTMLInjection {
        .styleAttribute(
            on: .html,
            css: (rsProperties.css() ?? "") + (userProperties.css() ?? "")
        )
    }

    /// Inject the `dir` attribute in `html` and `body`.
    ///
    /// https://github.com/readium/readium-css/blob/develop/docs/CSS16-internationalization.md#direction
    private func dirInjection() -> [HTMLInjection] {
        guard let rtl = layout.stylesheets.htmlDir.isRTL else {
            return []
        }

        return [
            .dirAttribute(on: .html, rtl: rtl),
            .dirAttribute(on: .body, rtl: rtl),
        ]
    }

    /// Injects the `xml:lang` attribute in `html` and `body`.
    ///
    /// https://github.com/readium/readium-css/blob/develop/docs/CSS16-internationalization.md#language
    private func langInjections(for document: Document) throws -> [HTMLInjection] {
        guard
            let language = layout.language,
            let html = try document.getElementsByTag("html").first(),
            !html.hasLang(),
            let body = document.body()
        else {
            return []
        }

        if body.hasLang() {
            return [
                .langAttribute(on: .html, language: body.lang() ?? language),
            ]
        } else {
            return [
                .langAttribute(on: .html, language: language),
                .langAttribute(on: .body, language: language),
            ]
        }
    }
}

private extension Element {
    func hasLang() -> Bool {
        hasAttr("xml:lang") || hasAttr("lang")
    }

    func lang() -> Language? {
        let code = (try? attr("xml:lang")).takeIf { !$0.isEmpty }
            ?? (try? attr("lang")).takeIf { !$0.isEmpty }

        return code.map { Language(code: .bcp47($0)) }
    }
}

private let dirRegex = try! NSRegularExpression(
    pattern: "(<(?:html|body)[^>]*)\\s+dir=[\"']\\w*[\"']",
    options: [.caseInsensitive, .anchorsMatchLines]
)
