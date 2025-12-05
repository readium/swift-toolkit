//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import XCTest

class ReadiumCSSTests: XCTestCase {
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

    func testInjectionsWithoutAnyStyle() {
        let css = ReadiumCSS(
            layout: CSSLayout(),
            rsProperties: CSSRSProperties(),
            userProperties: CSSUserProperties(),
            baseURL: baseURL
        )

        XCTAssertEqual(
            try css.injections(for: html),
            [
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

    func testInjectionsWithPublicationStyles() {
        let css = ReadiumCSS(
            layout: CSSLayout(),
            rsProperties: CSSRSProperties(),
            userProperties: CSSUserProperties(),
            baseURL: baseURL
        )

        XCTAssertFalse(
            try css.injections(for: """
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

        XCTAssertFalse(
            try css.injections(for: """
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

        XCTAssertFalse(
            try css.injections(for: """
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

    func testInjectionsWithReadiumCSSProperties() {
        let css = ReadiumCSS(
            layout: CSSLayout(),
            rsProperties: CSSRSProperties(
                colGap: CSSPxLength(40.0),
                textColor: CSSHexColor("#FF0000")
            ),
            userProperties: CSSUserProperties(
                appearance: .night,
                wordSpacing: CSSRemLength(20.0)
            ),
            baseURL: baseURL
        )

        XCTAssertEqual(
            try css.injections(for: html),
            [
                viewportMeta,
                cssBefore(),
                cssDefault(),
                cssAfter(),
                audioFix,
                .styleAttribute(on: .html, css: """
                --RS__colGap: 40.00000px !important;
                --RS__textColor: #FF0000 !important;
                --USER__appearance: readium-night-on !important;
                --USER__wordSpacing: 20.00000rem !important;

                """),
                .dirAttribute(on: .html, rtl: false),
                .dirAttribute(on: .body, rtl: false),
            ]
        )
    }

    func testInjectRTLDirStylesheets() {
        let css = ReadiumCSS(
            layout: CSSLayout(stylesheets: .rtl),
            rsProperties: CSSRSProperties(),
            userProperties: CSSUserProperties(),
            baseURL: baseURL
        )

        XCTAssertEqual(
            try css.injections(for: html),
            [
                viewportMeta,
                cssBefore(folder: "rtl/"),
                cssDefault(folder: "rtl/"),
                cssAfter(folder: "rtl/"),
                audioFix,
                .styleAttribute(on: .html, css: ""),
                .dirAttribute(on: .html, rtl: true),
                .dirAttribute(on: .body, rtl: true),
            ]
        )
    }

    func testInjectCJKHorizontalStylesheets() {
        let css = ReadiumCSS(
            layout: CSSLayout(stylesheets: .cjkHorizontal),
            rsProperties: CSSRSProperties(),
            userProperties: CSSUserProperties(),
            baseURL: baseURL
        )

        XCTAssertEqual(
            try css.injections(for: html),
            [
                viewportMeta,
                cssBefore(folder: "cjk-horizontal/"),
                cssDefault(folder: "cjk-horizontal/"),
                cssAfter(folder: "cjk-horizontal/"),
                audioFix,
                .styleAttribute(on: .html, css: ""),
                .dirAttribute(on: .html, rtl: false),
                .dirAttribute(on: .body, rtl: false),
            ]
        )
    }

    func testInjectCJKVerticalStylesheets() {
        let css = ReadiumCSS(
            layout: CSSLayout(stylesheets: .cjkVertical),
            rsProperties: CSSRSProperties(),
            userProperties: CSSUserProperties(),
            baseURL: baseURL
        )

        XCTAssertEqual(
            try css.injections(for: html),
            [
                viewportMeta,
                cssBefore(folder: "cjk-vertical/"),
                cssDefault(folder: "cjk-vertical/"),
                cssAfter(folder: "cjk-vertical/"),
                audioFix,
                .styleAttribute(on: .html, css: ""),
            ]
        )
    }

    func testInjectLangAttributes() {
        let language = Language(code: .bcp47("en"))
        let css = ReadiumCSS(
            layout: CSSLayout(language: language),
            baseURL: baseURL
        )

        XCTAssertEqual(
            try css.injections(for: """
            <?xml version="1.0" encoding="utf-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
                <head>
                    <title>Publication</title>
                </head>
                <body></body>
            </html>
            """),
            [
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

    func testInjectLangAttributesWhenOneExistsOnHTMLTag() {
        let css = ReadiumCSS(
            layout: CSSLayout(language: Language(code: .bcp47("en"))),
            baseURL: baseURL
        )

        XCTAssertEqual(
            try css.injections(for: """
            <?xml version="1.0" encoding="utf-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml" lang="fr">
                <head>
                    <title>Publication</title>
                </head>
                <body></body>
            </html>
            """),
            [
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

    func testInjectLangAttributesCopiesTheOneFromBodyTag() {
        let css = ReadiumCSS(
            layout: CSSLayout(language: Language(code: .bcp47("en"))),
            baseURL: baseURL
        )

        XCTAssertEqual(
            try css.injections(for: """
            <?xml version="1.0" encoding="utf-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
                <head>
                    <title>Publication</title>
                </head>
                <body lang="fr"></body>
            </html>
            """),
            [
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

    func testInjectDirAttributeWhenAlreadyPresent() {
        let css = ReadiumCSS(
            layout: CSSLayout(language: Language(code: .bcp47("en"))),
            baseURL: baseURL
        )

        XCTAssertEqual(
            try css.inject(in: """
            <?xml version="1.0" encoding="utf-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
                <head>
                    <title>Publication</title>
                </head>
                <body dir="rtl" lang="fr"></body>
            </html>
            """),
            """
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
}
