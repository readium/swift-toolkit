//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing
import UIKit

struct ReadiumCSSTests {
    let baseURL = HTTPURL(string: "https://readium/assets")!

    let viewportMeta = HTMLInjection.meta(name: "viewport", content: "width=device-width, height=device-height, initial-scale=1.0")

    func cssBefore(folder: String = "") -> HTMLInjection {
        .stylesheetLink(href: "https://readium/assets/\(folder)ReadiumCSS-before.css", prepend: true)
    }

    func cssDefault(folder: String = "") -> HTMLInjection {
        .stylesheetLink(href: "https://readium/assets/\(folder)ReadiumCSS-default.css")
    }

    func cssAfter(folder: String = "") -> HTMLInjection {
        .stylesheetLink(href: "https://readium/assets/\(folder)ReadiumCSS-after.css")
    }

    let audioFix = HTMLInjection.style("audio[controls] { width: revert; height: revert; }")

    let html =
        """
        <?xml version="1.0" encoding="utf-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
                <title>Publication</title>
            </head>
            <body></body>
        </html>
        """

    @Test func injectionsWithoutAnyStyle() throws {
        let css = ReadiumCSS(baseURL: baseURL)

        #expect(
            try css.injections(for: html) == [
                viewportMeta,
                cssBefore(),
                cssDefault(),
                cssAfter(),
                audioFix,
                .styleAttribute(on: .html, css: ""),
                .dirAttribute(on: .html, rtl: false),
                .dirAttribute(on: .body, rtl: false),
            ]
        )
    }

    @Test func injectionsWithPublicationStyles() throws {
        let css = ReadiumCSS(baseURL: baseURL)

        #expect(
            try !css.injections(for: """
            <?xml version="1.0" encoding="utf-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
                <head>
                    <title>Publication</title>
                    <link rel="stylesheet" href="style.css" type="text/css"/>
                </head>
                <body></body>
            </html>
            """).contains(cssDefault())
        )

        #expect(
            try !css.injections(for: """
            <?xml version="1.0" encoding="utf-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
                <head>
                    <title>Publication</title>
                    <style>font-size: 1em;</style>
                </head>
                <body></body>
            </html>
            """).contains(cssDefault())
        )

        #expect(
            try !css.injections(for: """
            <?xml version="1.0" encoding="utf-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
                <head>
                    <title>Publication</title>
                </head>
                <body>
                    <p style="color: black;"></p>
                </body>
            </html>
            """).contains(cssDefault())
        )
    }

    @Test func injectionsWithReadiumCSSProperties() throws {
        let css = ReadiumCSS(
            rsProperties: CSSRSProperties(
                colGap: CSSPxLength(40.0),
                textColor: CSSHexColor("#FF0000")
            ),
            userProperties: CSSUserProperties(
                linkColor: CSSHexColor("#0000FF"),
                wordSpacing: CSSRemLength(20.0)
            ),
            baseURL: baseURL
        )

        #expect(
            try css.injections(for: html) == [
                viewportMeta,
                cssBefore(),
                cssDefault(),
                cssAfter(),
                audioFix,
                .styleAttribute(on: .html, css: """
                --RS__colGap: 40.00000px !important;
                --RS__textColor: #FF0000 !important;
                --USER__linkColor: #0000FF !important;
                --USER__wordSpacing: 20.00000rem !important;

                """),
                .dirAttribute(on: .html, rtl: false),
                .dirAttribute(on: .body, rtl: false),
            ]
        )
    }

    /// The `dir` attributes are injected only with a horizontal direction.
    @Test(arguments: [
        (CSSLayout.Stylesheets.rtl, "rtl/", true),
        (.cjkHorizontal, "cjk-horizontal/", false),
        (.cjkVertical, "cjk-vertical/", nil),
    ] as [(CSSLayout.Stylesheets, String, Bool?)])
    func injectStylesheetsFromTheirFolder(stylesheets: CSSLayout.Stylesheets, folder: String, rtl: Bool?) throws {
        let css = ReadiumCSS(layout: CSSLayout(stylesheets: stylesheets), baseURL: baseURL)
        let dirAttributes: [HTMLInjection] = rtl.map {
            [.dirAttribute(on: .html, rtl: $0), .dirAttribute(on: .body, rtl: $0)]
        } ?? []

        #expect(
            try css.injections(for: html) == [
                viewportMeta,
                cssBefore(folder: folder),
                cssDefault(folder: folder),
                cssAfter(folder: folder),
                audioFix,
                .styleAttribute(on: .html, css: ""),
            ] + dirAttributes
        )
    }

    @Test func injectLangAttributes() throws {
        let language = Language(code: .bcp47("en"))
        let css = ReadiumCSS(
            layout: CSSLayout(language: language),
            baseURL: baseURL
        )

        #expect(
            try css.injections(for: """
            <?xml version="1.0" encoding="utf-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
                <head>
                    <title>Publication</title>
                </head>
                <body></body>
            </html>
            """) == [
                viewportMeta,
                cssBefore(),
                cssDefault(),
                cssAfter(),
                audioFix,
                .styleAttribute(on: .html, css: ""),
                .dirAttribute(on: .html, rtl: false),
                .dirAttribute(on: .body, rtl: false),
                .langAttribute(on: .html, language: language),
                .langAttribute(on: .body, language: language),
            ]
        )
    }

    @Test func injectLangAttributesWhenOneExistsOnHTMLTag() throws {
        let css = ReadiumCSS(
            layout: CSSLayout(language: Language(code: .bcp47("en"))),
            baseURL: baseURL
        )

        #expect(
            try css.injections(for: """
            <?xml version="1.0" encoding="utf-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml" lang="fr">
                <head>
                    <title>Publication</title>
                </head>
                <body></body>
            </html>
            """) == [
                viewportMeta,
                cssBefore(),
                cssDefault(),
                cssAfter(),
                audioFix,
                .styleAttribute(on: .html, css: ""),
                .dirAttribute(on: .html, rtl: false),
                .dirAttribute(on: .body, rtl: false),
            ]
        )
    }

    @Test func injectLangAttributesCopiesTheOneFromBodyTag() throws {
        let css = ReadiumCSS(
            layout: CSSLayout(language: Language(code: .bcp47("en"))),
            baseURL: baseURL
        )

        #expect(
            try css.injections(for: """
            <?xml version="1.0" encoding="utf-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
                <head>
                    <title>Publication</title>
                </head>
                <body lang="fr"></body>
            </html>
            """) == [
                viewportMeta,
                cssBefore(),
                cssDefault(),
                cssAfter(),
                audioFix,
                .styleAttribute(on: .html, css: ""),
                .dirAttribute(on: .html, rtl: false),
                .dirAttribute(on: .body, rtl: false),
                .langAttribute(on: .html, language: Language(code: .bcp47("fr"))),
            ]
        )
    }

    // MARK: - langInjections(for:) via injections(for:)

    @Test func noLangInjectionWhenNoLanguageSet() throws {
        let css = ReadiumCSS(baseURL: baseURL)

        #expect(
            try css.injections(for: html) == [
                viewportMeta,
                cssBefore(),
                cssDefault(),
                cssAfter(),
                audioFix,
                .styleAttribute(on: .html, css: ""),
                .dirAttribute(on: .html, rtl: false),
                .dirAttribute(on: .body, rtl: false),
            ]
        )
    }

    @Test func langInjectionFallsBackToLayoutLangWhenBodyLangIsEmpty() throws {
        let language = Language(code: .bcp47("en"))
        let css = ReadiumCSS(
            layout: CSSLayout(language: language),
            baseURL: baseURL
        )

        #expect(
            try css.injections(for: """
            <?xml version="1.0" encoding="utf-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
                <head>
                    <title>Publication</title>
                </head>
                <body lang=""></body>
            </html>
            """) == [
                viewportMeta,
                cssBefore(),
                cssDefault(),
                cssAfter(),
                audioFix,
                .styleAttribute(on: .html, css: ""),
                .dirAttribute(on: .html, rtl: false),
                .dirAttribute(on: .body, rtl: false),
                .langAttribute(on: .html, language: language),
                .langAttribute(on: .body, language: language),
            ]
        )
    }

    @Test func injectDirAttributeWhenAlreadyPresent() throws {
        let css = ReadiumCSS(
            layout: CSSLayout(language: Language(code: .bcp47("en"))),
            baseURL: baseURL
        )

        #expect(
            try css.inject(in: """
            <?xml version="1.0" encoding="utf-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
                <head>
                    <title>Publication</title>
                </head>
                <body dir="rtl" lang="fr"></body>
            </html>
            """) == """
            <?xml version="1.0" encoding="utf-8"?>
            <html xml:lang="fr" dir="ltr" style="" xmlns="http://www.w3.org/1999/xhtml">
                <head><link rel="stylesheet" href="https://readium/assets/ReadiumCSS-before.css" type="text/css"/>
                    <title>Publication</title>
                <meta name="viewport" content="width=device-width, height=device-height, initial-scale=1.0"/><link rel="stylesheet" href="https://readium/assets/ReadiumCSS-default.css" type="text/css"/><link rel="stylesheet" href="https://readium/assets/ReadiumCSS-after.css" type="text/css"/><style type="text/css">audio[controls] { width: revert; height: revert; }</style></head>
                <body dir="ltr" lang="fr"></body>
            </html>
            """
        )
    }

    @Test @MainActor func updateResolvesTheFontFamilyAlternates() {
        var css = ReadiumCSS(
            baseURL: baseURL,
            fontFamilyDeclarations: [
                CSSFontFamilyDeclaration(fontFamily: "Literata", alternates: ["IA Writer Duospace"])
                    .eraseToAnyHTMLFontFamilyDeclaration(),
                CSSFontFamilyDeclaration(fontFamily: "IA Writer Duospace", alternates: [.serif])
                    .eraseToAnyHTMLFontFamilyDeclaration(),
            ]
        )
        css.update(with: EPUBSettings(preferences: EPUBPreferences(fontFamily: "Literata"), defaults: EPUBDefaults(), metadata: Metadata(title: "Test")))
        #expect(css.userProperties.cssProperties()["--USER__fontFamily"] == #"Literata, "IA Writer Duospace", serif"#)
    }

    @Test(arguments: [false, true])
    @MainActor func updateDoesNotSetPageGutter(scroll: Bool) {
        var css = ReadiumCSS(baseURL: baseURL)
        let settings = EPUBSettings(
            preferences: EPUBPreferences(pageMargins: 1.5, scroll: scroll),
            defaults: EPUBDefaults(),
            metadata: Metadata(title: "Test")
        )
        css.update(with: settings)
        #expect(css.rsProperties.pageGutter == nil)

        css.update(with: settings, resolvedLayout: LayoutResolver.Layout(colCount: 1, lineLength: 500.0))
        #expect(css.rsProperties.pageGutter == nil)
    }

    @Test(arguments: [false, true])
    @MainActor func updateWithoutLayoutOmitsLayoutProperties(scroll: Bool) {
        var css = ReadiumCSS(baseURL: baseURL)
        let settings = EPUBSettings(
            preferences: EPUBPreferences(columnCount: 2, scroll: scroll),
            defaults: EPUBDefaults(),
            metadata: Metadata(title: "Test")
        )
        css.update(with: settings, safeAreaInsets: UIEdgeInsets(top: 44, left: 20, bottom: 34, right: 25))

        let props = css.userProperties.cssProperties()
        #expect(props["--USER__colCount"] == .some(nil))
        #expect(props["--USER__lineLength"] == .some(nil))
        let rsProps = css.rsProperties.cssProperties()
        #expect(rsProps["--RS__scrollPaddingTop"] == .some(nil))
        #expect(rsProps["--RS__scrollPaddingBottom"] == .some(nil))
        #expect(rsProps["--RS__scrollPaddingLeft"] == .some(nil))
        #expect(rsProps["--RS__scrollPaddingRight"] == .some(nil))
    }

    @Test @MainActor func updateWithLayoutAppliesColCountAndLineLength() {
        var css = ReadiumCSS(baseURL: baseURL)
        let settings = EPUBSettings(
            preferences: EPUBPreferences(fontSize: 2.0),
            defaults: EPUBDefaults(),
            metadata: Metadata(title: "Test")
        )
        let layout = LayoutResolver.Layout(colCount: 2, lineLength: 640.0)
        css.update(with: settings, resolvedLayout: layout)

        #expect(
            css.userProperties.cssProperties()["--USER__colCount"] == "2"
        )
        #expect(
            css.userProperties.cssProperties()["--USER__lineLength"] == "320.00000px"
        )
    }

    @Test @MainActor func updateWithLayoutAndScrollSettingsComputesScrollPaddingFromInsets() {
        var css = ReadiumCSS(baseURL: baseURL)
        let settings = EPUBSettings(
            preferences: EPUBPreferences(scroll: true),
            defaults: EPUBDefaults(),
            metadata: Metadata(title: "Test")
        )
        let insets = UIEdgeInsets(top: 44, left: 20, bottom: 34, right: 25)
        let layout = LayoutResolver.Layout(colCount: 1, lineLength: 500.0)
        css.update(with: settings, resolvedLayout: layout, safeAreaInsets: insets)

        #expect(
            css.rsProperties.cssProperties()["--RS__scrollPaddingTop"] == "44.00000px"
        )
        #expect(
            css.rsProperties.cssProperties()["--RS__scrollPaddingBottom"] == "34.00000px"
        )
    }
}
