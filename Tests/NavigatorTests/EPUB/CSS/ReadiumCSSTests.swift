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
                noOverflow: true
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
                --RS__disableOverflow: readium-noOverflow-on !important;
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

    @Test func updateResolvesTheFontFamilyAlternates() {
        var css = ReadiumCSS(
            baseURL: baseURL,
            fontFamilyDeclarations: [
                CSSFontFamilyDeclaration(fontFamily: "Literata", alternates: ["IA Writer Duospace"])
                    .eraseToAnyHTMLFontFamilyDeclaration(),
                CSSFontFamilyDeclaration(fontFamily: "IA Writer Duospace", alternates: [.serif])
                    .eraseToAnyHTMLFontFamilyDeclaration(),
            ]
        )
        css.update(
            with: EPUBSettings(preferences: EPUBPreferences(fontFamily: "Literata"), defaults: EPUBDefaults(), metadata: Metadata(title: "Test")),
            userInterfaceIdiom: .pad
        )
        #expect(css.userProperties.cssProperties()["--USER__fontFamily"] == #"Literata, "IA Writer Duospace", serif"#)
    }

    struct PatchCase: Sendable, CustomTestStringConvertible {
        let name: String
        let idiom: UIUserInterfaceIdiom
        let patches: [String: String]

        var testDescription: String {
            name
        }
    }

    @Test(arguments: [
        PatchCase(name: "iPhone", idiom: .phone, patches: ["--USER__iOSPatch": "readium-iOSPatch-on"]),
        PatchCase(name: "iPad", idiom: .pad, patches: ["--USER__iPadOSPatch": "readium-iPadOSPatch-on"]),
        PatchCase(name: "Mac", idiom: .mac, patches: [:]),
        PatchCase(name: "unspecified device", idiom: .unspecified, patches: [:]),
    ])
    func updateAppliesTheWebKitPatchOfTheDevice(_ test: PatchCase) {
        var css = ReadiumCSS(baseURL: baseURL)
        css.update(
            with: EPUBSettings(preferences: EPUBPreferences(), defaults: EPUBDefaults(), metadata: Metadata(title: "Test")),
            userInterfaceIdiom: test.idiom
        )
        let userProps = css.userProperties.cssProperties().compactMapValues { $0 }
        #expect(userProps.filter { $0.key.hasSuffix("Patch") } == test.patches)
        #expect(css.rsProperties.cssProperties()["--RS__disableOverflow"] == "readium-noOverflow-on")
    }

    /// The complete inline CSS emitted for each device, with the default
    /// settings and a resolved layout.
    @Test(arguments: [
        (UIUserInterfaceIdiom.phone, """
        --RS__disableOverflow: readium-noOverflow-on !important;
        --USER__colCount: 1 !important;
        --USER__fontSize: 100.00000% !important;
        --USER__iOSPatch: readium-iOSPatch-on !important;
        --USER__lineLength: 578.00000px !important;
        --USER__view: readium-paged-on !important;

        """),
        (.pad, """
        --RS__disableOverflow: readium-noOverflow-on !important;
        --USER__colCount: 1 !important;
        --USER__fontSize: 100.00000% !important;
        --USER__iPadOSPatch: readium-iPadOSPatch-on !important;
        --USER__lineLength: 578.00000px !important;
        --USER__view: readium-paged-on !important;

        """),
        (.mac, """
        --RS__disableOverflow: readium-noOverflow-on !important;
        --USER__colCount: 1 !important;
        --USER__fontSize: 100.00000% !important;
        --USER__lineLength: 578.00000px !important;
        --USER__view: readium-paged-on !important;

        """),
        (.unspecified, """
        --RS__disableOverflow: readium-noOverflow-on !important;
        --USER__colCount: 1 !important;
        --USER__fontSize: 100.00000% !important;
        --USER__lineLength: 578.00000px !important;
        --USER__view: readium-paged-on !important;

        """),
    ])
    func updateEmitsTheInlineCSSOfTheDevice(idiom: UIUserInterfaceIdiom, expected: String) throws {
        var css = ReadiumCSS(baseURL: baseURL)
        css.update(
            with: EPUBSettings(preferences: EPUBPreferences(), defaults: EPUBDefaults(), metadata: Metadata(title: "Test")),
            userInterfaceIdiom: idiom,
            resolvedLayout: LayoutResolver.Layout(colCount: 1, lineLength: 578)
        )
        #expect(try css.injections(for: html).contains(.styleAttribute(on: .html, css: expected)))
    }

    @Test(arguments: [false, true])
    func updateWithoutLayoutOmitsLayoutProperties(scroll: Bool) {
        var css = ReadiumCSS(baseURL: baseURL)
        let settings = EPUBSettings(
            preferences: EPUBPreferences(columnCount: 2, scroll: scroll),
            defaults: EPUBDefaults(),
            metadata: Metadata(title: "Test")
        )
        css.update(with: settings, userInterfaceIdiom: .pad)

        let props = css.userProperties.cssProperties()
        #expect(props["--USER__colCount"] == .some(nil))
        #expect(props["--USER__lineLength"] == .some(nil))
    }

    struct LineLengthCase: Sendable, CustomTestStringConvertible {
        let name: String
        let idiom: UIUserInterfaceIdiom
        let lineLength: String

        var testDescription: String {
            name
        }
    }

    /// The line length is divided by the font size to compensate the `zoom`
    /// on `body`, except on iPhone where the iOS patch scales the text with
    /// `-webkit-text-size-adjust` instead.
    @Test(arguments: [
        LineLengthCase(name: "iPhone", idiom: .phone, lineLength: "640.00000px"),
        LineLengthCase(name: "iPad", idiom: .pad, lineLength: "320.00000px"),
        LineLengthCase(name: "Mac", idiom: .mac, lineLength: "320.00000px"),
    ])
    func updateWithLayoutAppliesColCountAndLineLength(_ test: LineLengthCase) {
        var css = ReadiumCSS(baseURL: baseURL)
        let settings = EPUBSettings(
            preferences: EPUBPreferences(fontSize: 2.0),
            defaults: EPUBDefaults(),
            metadata: Metadata(title: "Test")
        )
        let layout = LayoutResolver.Layout(colCount: 2, lineLength: 640.0)
        css.update(with: settings, userInterfaceIdiom: test.idiom, resolvedLayout: layout)

        #expect(
            css.userProperties.cssProperties()["--USER__colCount"] == "2"
        )
        #expect(
            css.userProperties.cssProperties()["--USER__lineLength"] == .some(test.lineLength)
        )
    }

    /// A font size of 0 is ignored by the settings, so neither a `0%` font
    /// size nor a line length divided by 0 is emitted.
    @Test(arguments: [UIUserInterfaceIdiom.phone, .pad, .mac])
    func updateWithZeroFontSizeKeepsLineLength(idiom: UIUserInterfaceIdiom) {
        var css = ReadiumCSS(baseURL: baseURL)
        let settings = EPUBSettings(
            preferences: EPUBPreferences(fontSize: 0),
            defaults: EPUBDefaults(),
            metadata: Metadata(title: "Test")
        )
        css.update(with: settings, userInterfaceIdiom: idiom, resolvedLayout: LayoutResolver.Layout(colCount: 1, lineLength: 712))

        let props = css.userProperties.cssProperties()
        #expect(props["--USER__fontSize"] == "100.00000%")
        #expect(props["--USER__lineLength"] == "712.00000px")
    }

    // MARK: - EBPAJ fonts patch

    let ebpajFontsPatch = HTMLInjection.stylesheetLink(href: "https://readium/assets/ReadiumCSS-ebpaj_fonts_patch.css")

    /// The patch is appended after `ReadiumCSS-after.css` with the CJK layouts.
    @Test(arguments: [
        (CSSLayout.Stylesheets.cjkHorizontal, "cjk-horizontal/"),
        (.cjkVertical, "cjk-vertical/"),
    ])
    func injectEBPAJFontsPatchWithCJKLayouts(stylesheets: CSSLayout.Stylesheets, folder: String) throws {
        let css = ReadiumCSS(layout: CSSLayout(stylesheets: stylesheets), baseURL: baseURL, isEBPAJ: true)

        let styles = try css.injections(for: html).filter { $0.target == .head && $0 != viewportMeta }
        #expect(styles == [
            cssBefore(folder: folder),
            cssDefault(folder: folder),
            cssAfter(folder: folder),
            ebpajFontsPatch,
            audioFix,
        ])
    }

    @Test(arguments: [CSSLayout.Stylesheets.default, .rtl])
    func doNotInjectEBPAJFontsPatchWithOtherLayouts(stylesheets: CSSLayout.Stylesheets) throws {
        let css = ReadiumCSS(layout: CSSLayout(stylesheets: stylesheets), baseURL: baseURL, isEBPAJ: true)

        #expect(try !css.injections(for: html).contains(ebpajFontsPatch))
    }

    @Test(arguments: [CSSLayout.Stylesheets.cjkHorizontal, .cjkVertical])
    func doNotInjectEBPAJFontsPatchWithoutEBPAJ(stylesheets: CSSLayout.Stylesheets) throws {
        let css = ReadiumCSS(layout: CSSLayout(stylesheets: stylesheets), baseURL: baseURL, isEBPAJ: false)

        #expect(try !css.injections(for: html).contains(ebpajFontsPatch))
    }

    @Test(arguments: [
        (Metadata(title: "Test", description: "ebpaj-guide-1.0"), true),
        (Metadata(title: "Test", otherMetadata: ["http://www.ebpaj.jp/guide-version": "1.1.3"]), true),
        (Metadata(title: "Test", otherMetadata: ["ebpaj:guide-version": "1.1.3"]), true),
        (Metadata(title: "Test"), false),
        (Metadata(title: "Test", description: "A Japanese novel."), false),
        (Metadata(title: "Test", otherMetadata: ["http://idpf.org/epub/vocab/package/#guide-version": "1.1.3"]), false),
    ])
    func metadataIsEBPAJ(metadata: Metadata, expected: Bool) {
        #expect(metadata.isEBPAJ == expected)
    }
}
