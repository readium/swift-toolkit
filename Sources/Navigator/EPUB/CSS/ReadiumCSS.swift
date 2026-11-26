//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

struct ReadiumCSS {
    var layout: CSSLayout = .init()
    var rsProperties: CSSRSProperties = .init()
    var userProperties: CSSUserProperties = .init()

    /// Base URL of the Readium CSS assets.
    var baseURL: any AbsoluteURL

    var fontFamilyDeclarations: [AnyHTMLFontFamilyDeclaration] = []

    /// Indicates whether the publication follows the EBPAJ EPUB 3 production
    /// guide, which requires the Readium CSS EBPAJ fonts patch with the CJK
    /// layouts.
    var isEBPAJ: Bool = false
}

extension ReadiumCSS {
    /// Default background color of the Readium CSS stylesheets, used when the
    /// user background color is unset and the publication doesn't have its
    /// own.
    static let defaultBackgroundColor = Color(rawValue: 0xFFFFFF)
}

extension ReadiumCSS {
    mutating func update(
        with settings: EPUBSettings,
        userInterfaceIdiom: UIUserInterfaceIdiom,
        resolvedLayout: LayoutResolver.Layout? = nil
    ) {
        layout = settings.cssLayout

        // See https://github.com/readium/css/issues/183
        rsProperties = CSSRSProperties(noOverflow: true)

        // Readium CSS applies `--USER__fontSize` with a `zoom` on `body`,
        // which also scales the line length in px set below. It is divided by
        // this `zoom` to compensate it, as the resolved line length already
        // follows the font size, with the same factor (see `LayoutResolver`).
        var bodyZoom = settings.fontSize

        // Applies the WebKit patch matching the device:
        // - iOSPatch on iPhone. The text is then scaled with
        //   `-webkit-text-size-adjust` instead, without any `zoom`.
        // - iPadOSPatch on iPad, where WebKit requests the pages as desktop.
        //   An iPad app running on an Apple silicon Mac ("Designed for iPad")
        //   reports an iPad too and gets it on purpose, as it uses the same
        //   WebKit and also requests the pages as desktop.
        // - Nothing for a Mac Catalyst app optimized for the Mac.
        //
        // See https://github.com/readium/css/issues/189
        let iOSPatch = userInterfaceIdiom == .phone
        let iPadOSPatch = userInterfaceIdiom == .pad
        if iOSPatch {
            bodyZoom = 1
        }

        // The margins around the lines come from the resolved `lineLength`,
        // so `--RS__pageGutter` is not set: `body` is `border-box`, so the
        // gutter would be added to these margins.
        //
        // The `--RS__scrollPadding*` properties are not set either: in scroll
        // mode, the content inset of the web view's scroll view already
        // applies the safe area (see `EPUBReflowableSpreadView`).

        userProperties = CSSUserProperties(
            view: settings.scroll ? .scroll : .paged,
            // The layout is resolved once the viewport size is known.
            colCount: resolvedLayout?.colCount,
            lineLength: resolvedLayout.map { CSSPxLength($0.lineLength / bodyZoom) },
            blendImages: settings.blendImages,
            // An image filter which is off is not emitted, as the presence of
            // the property is enough to trigger the Readium CSS rule. For
            // example, `--USER__invertGaiji: 0` would exclude the gaiji from
            // the other image filters. `darkenImages` is off below 0.00001,
            // such as the residue of stepping it down to 0%.
            darkenImages: settings.darkenImages.takeIf { $0 >= 0.00001 }.map { 1 - $0 },
            invertImages: settings.invertImages ? 1.0 : nil,
            invertGaiji: settings.invertGaiji ? 1.0 : nil,
            textColor: settings.textColor.map { CSSIntColor($0.rawValue) },
            backgroundColor: settings.backgroundColor.map { CSSIntColor($0.rawValue) },
            linkColor: settings.linkColor.map { CSSIntColor($0.rawValue) },
            visitedColor: settings.visitedColor.map { CSSIntColor($0.rawValue) },
            fontFamily: settings.fontFamily.map(resolveFontStack),
            fontSize: CSSPercentLength(settings.fontSize),
            fontWeight: settings.fontWeight
                .map { Double(CSSStandardFontWeight.normal.rawValue) * $0 }
                .takeIf { !$0.isNaN }
                .map { Int($0.clamped(to: 1 ... 1000).rounded()) },
            fontWidth: settings.fontWidth.map { CSSPercentLength($0) },
            textAlign: {
                switch settings.textAlign {
                case .justify: return .justify
                case .left: return .left
                case .right: return .right
                case .start, .center, .end: return .start
                default: return nil
                }
            }(),
            lineHeight: settings.lineHeight,
            paraSpacing: settings.paragraphSpacing.map { CSSRemLength($0) },
            paraIndent: settings.paragraphIndent.map { CSSRemLength($0) },
            wordSpacing: settings.wordSpacing.map { CSSRemLength($0) },
            letterSpacing: settings.letterSpacing.map { CSSRemLength($0 / 2) },
            bodyHyphens: settings.hyphens.map { $0 ? .auto : .none },
            ligatures: settings.ligatures.map { $0 ? .common : .none },
            a11yNormalize: settings.textNormalization,
            noRuby: settings.noRuby,
            iOSPatch: iOSPatch,
            iPadOSPatch: iPadOSPatch
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

    /// https://github.com/readium/css/blob/develop/docs/CSS06-stylesheets_order.md
    func injections(for html: String) throws -> [HTMLInjection] {
        var inj: [HTMLInjection] = []
        inj.append(.meta(name: "viewport", content: "width=device-width, height=device-height, initial-scale=1.0"))
        inj.append(contentsOf: styleInjections(for: html))
        inj.append(cssPropertiesInjection())
        inj.append(contentsOf: dirInjection())
        inj.append(contentsOf: langInjections(for: html))
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

        // The EBPAJ template declares its font families with Windows fonts
        // only. The patch adds the fonts of the other platforms, and must be
        // appended after the other stylesheets to override the author's
        // `@font-face` rules.
        // https://github.com/readium/css/blob/develop/css/dist/ReadMe.md#ebpaj-polyfill
        //
        // Readium CSS only requires the EBPAJ metadata. Restricting the patch
        // to the CJK layouts is our choice, as in the TypeScript toolkit. Like
        // all the Readium CSS stylesheets, it is only injected in reflowable
        // resources.
        if isEBPAJ, layout.stylesheets.isCJK {
            inj.append(.stylesheetLink(href: baseURL.appendingPath("ReadiumCSS-ebpaj_fonts_patch.css", isDirectory: false).string))
        }

        // Fix Readium CSS issue with the positioning of <audio> elements.
        // https://github.com/readium/css/issues/94
        // https://github.com/readium/r2-navigator-kotlin/issues/193
        inj.append(.style("audio[controls] { width: revert; height: revert; }"))

        return inj
    }

    /// Returns whether the given `html` has any CSS styles.
    ///
    /// https://github.com/readium/css/blob/develop/docs/CSS06-stylesheets_order.md#append-if-there-is-no-authors-styles
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
    /// https://github.com/readium/css/blob/develop/docs/CSS16-internationalization.md#direction
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
    /// https://github.com/readium/css/blob/develop/docs/CSS16-internationalization.md#language
    private func langInjections(for html: String) -> [HTMLInjection] {
        let langAttrs = ["xml:lang", "lang"]
        guard
            let language = layout.language,
            !HTMLElement.html.hasAttribute(anyOf: langAttrs, in: html)
        else {
            return []
        }

        if
            let bodyLang = HTMLElement.body.attribute(firstOf: langAttrs, in: html),
            !bodyLang.isEmpty
        {
            return [
                .langAttribute(on: .html, language: Language(bodyLang)),
            ]
        } else {
            return [
                .langAttribute(on: .html, language: language),
                .langAttribute(on: .body, language: language),
            ]
        }
    }
}

private let dirRegex = try! NSRegularExpression(
    pattern: "(<(?:html|body)[^>]*)\\s+dir=[\"']\\w*[\"']",
    options: [.caseInsensitive, .anchorsMatchLines]
)
