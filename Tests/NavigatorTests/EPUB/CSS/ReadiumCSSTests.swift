//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest
import R2Shared
@testable import R2Navigator

class ReadiumCSSTests: XCTestCase {
    
    let assetsBaseURL = URL(string: "https://readium/assets")!
    
    let viewportMeta = HTMLInjection.meta(name: "viewport", content: "width=device-width, height=device-height, initial-scale=1.0;")
    
    func cssBefore(folder: String = "") -> HTMLInjection {
        .stylesheetLink(href: "https://readium/assets/readium/readium-css/\(folder)ReadiumCSS-before.css", prepend: true)
    }
    
    func cssDefault(folder: String = "") -> HTMLInjection {
        .stylesheetLink(href: "https://readium/assets/readium/readium-css/\(folder)ReadiumCSS-default.css")
    }
    
    func cssAfter(folder: String = "") -> HTMLInjection {
        .stylesheetLink(href: "https://readium/assets/readium/readium-css/\(folder)ReadiumCSS-after.css")
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
            assetsBaseURL: assetsBaseURL
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
            assetsBaseURL: assetsBaseURL
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
            assetsBaseURL: assetsBaseURL
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
                    --RS__colGap: 40px;
                    --RS__textColor: #FF0000;
                    --USER__appearance: readium-night-on;
                    --USER__wordSpacing: 20rem;
                    
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
            assetsBaseURL: assetsBaseURL
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
            assetsBaseURL: assetsBaseURL
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
            assetsBaseURL: assetsBaseURL
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
            assetsBaseURL: assetsBaseURL
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
            assetsBaseURL: assetsBaseURL
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
            assetsBaseURL: assetsBaseURL
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
                .langAttribute(on: .html, language: Language(code: .bcp47("fr")))
            ]
        )
    }
}
