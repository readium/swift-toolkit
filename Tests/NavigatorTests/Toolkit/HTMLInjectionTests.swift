//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import XCTest

class HTMLInjectionTests: XCTestCase {
    let html =
        """
        <html lang="en">
            <head><title>Test</title></head>
            <body>
                <p>Body</p>
            </body>
        </html>
        """

    func testInjectEmptyContent() {
        XCTAssertEqual(
            try HTMLInjection(
                content: "",
                target: .body,
                location: .start
            ).inject(in: html),
            """
            <html lang="en">
                <head><title>Test</title></head>
                <body>
                    <p>Body</p>
                </body>
            </html>
            """
        )
    }

    func testInjectSingleLine() {
        XCTAssertEqual(
            try HTMLInjection(
                content: "<p>Injected</p>",
                target: .body,
                location: .start
            ).inject(in: html),
            """
            <html lang="en">
                <head><title>Test</title></head>
                <body><p>Injected</p>
                    <p>Body</p>
                </body>
            </html>
            """
        )
    }

    func testInjectMultipleLines() {
        XCTAssertEqual(
            try HTMLInjection(
                content:
                """
                <p>
                Injected
                </p>
                """,
                target: .body,
                location: .start
            ).inject(in: html),
            """
            <html lang="en">
                <head><title>Test</title></head>
                <body><p>
            Injected
            </p>
                    <p>Body</p>
                </body>
            </html>
            """
        )
    }

    func testInjectInStart() {
        XCTAssertEqual(
            try HTMLInjection(
                content: "<p>Injected</p>",
                target: .body,
                location: .start
            ).inject(in: html),
            """
            <html lang="en">
                <head><title>Test</title></head>
                <body><p>Injected</p>
                    <p>Body</p>
                </body>
            </html>
            """
        )
    }

    func testInjectInEnd() {
        XCTAssertEqual(
            try HTMLInjection(
                content: "<p>Injected</p>",
                target: .body,
                location: .end
            ).inject(in: html),
            """
            <html lang="en">
                <head><title>Test</title></head>
                <body>
                    <p>Body</p>
                <p>Injected</p></body>
            </html>
            """
        )
    }

    func testInjectInAttributesWithNoAttributes() {
        XCTAssertEqual(
            try HTMLInjection(
                content: " attr='injected'",
                target: .body,
                location: .attributes
            ).inject(in: html),
            """
            <html lang="en">
                <head><title>Test</title></head>
                <body attr='injected'>
                    <p>Body</p>
                </body>
            </html>
            """
        )
    }

    func testInjectInAttributesWithExistingAttributes() {
        XCTAssertEqual(
            try HTMLInjection(
                content: " attr='injected'",
                target: .html,
                location: .attributes
            ).inject(in: html),
            """
            <html attr='injected' lang="en">
                <head><title>Test</title></head>
                <body>
                    <p>Body</p>
                </body>
            </html>
            """
        )
    }

    func testInjectionOfInjectable() {
        XCTAssertEqual(
            try InjectableFixture(injects: [
                HTMLInjection(
                    content: " attr1='value1'",
                    target: .body,
                    location: .attributes
                ),
                HTMLInjection(
                    content: "<p>Start1</p>",
                    target: .body,
                    location: .start
                ),
                HTMLInjection(
                    content: " attr2='value2'",
                    target: .body,
                    location: .attributes
                ),
                HTMLInjection(
                    content: "<p>End1</p>",
                    target: .body,
                    location: .end
                ),
                HTMLInjection(
                    content: "<p>End2</p>",
                    target: .body,
                    location: .end
                ),
                HTMLInjection(
                    content: "<p>Start2</p>",
                    target: .body,
                    location: .start
                ),
                HTMLInjection(
                    content: "<meta/>",
                    target: .head,
                    location: .end
                ),
            ]).inject(in: html),
            """
            <html lang="en">
                <head><title>Test</title><meta/></head>
                <body attr2='value2' attr1='value1'><p>Start2</p><p>Start1</p>
                    <p>Body</p>
                <p>End1</p><p>End2</p></body>
            </html>
            """
        )
    }

    struct InjectableFixture: HTMLInjectable {
        let injects: [HTMLInjection]

        func injections(for html: String) -> [HTMLInjection] {
            injects
        }
    }

    func testInjectionsOfHTMLAttribute() {
        XCTAssertEqual(
            HTMLInjection.attribute("test", on: .body, value: "value to \"escape\""),
            HTMLInjection(
                content: #" test="value to &quot;escape&quot;""#,
                target: .body,
                location: .attributes
            )
        )
    }

    func testInjectionsOfDirHTMLAttribute() {
        XCTAssertEqual(
            HTMLInjection.dirAttribute(on: .body, rtl: false),
            HTMLInjection(
                content: #" dir="ltr""#,
                target: .body,
                location: .attributes
            )
        )
        XCTAssertEqual(
            HTMLInjection.dirAttribute(on: .body, rtl: true),
            HTMLInjection(
                content: #" dir="rtl""#,
                target: .body,
                location: .attributes
            )
        )
    }

    func testInjectionsOfLangHTMLAttribute() {
        XCTAssertEqual(
            HTMLInjection.langAttribute(on: .body, language: Language(code: .bcp47("en"))),
            HTMLInjection(
                content: #" xml:lang="en""#,
                target: .body,
                location: .attributes
            )
        )
    }

    func testInjectionsOfStyleHTMLAttribute() {
        XCTAssertEqual(
            HTMLInjection.styleAttribute(on: .body, css: "background: \"red\";"),
            HTMLInjection(
                content: #" style="background: &quot;red&quot;;""#,
                target: .body,
                location: .attributes
            )
        )
    }

    func testInjectionsOfStylesheetLinkTagBefore() {
        XCTAssertEqual(
            HTMLInjection.stylesheetLink(href: "path/to/style.css", prepend: true),
            HTMLInjection(
                content: #"<link rel="stylesheet" href="path/to/style.css" type="text/css"/>"#,
                target: .head,
                location: .start
            )
        )
    }

    func testInjectionsOfStylesheetLinkTagAfter() {
        XCTAssertEqual(
            HTMLInjection.stylesheetLink(href: "path/to/style.css", prepend: false),
            HTMLInjection(
                content: #"<link rel="stylesheet" href="path/to/style.css" type="text/css"/>"#,
                target: .head,
                location: .end
            )
        )
    }

    func testInjectionsOfHTMLMetaTag() {
        XCTAssertEqual(
            HTMLInjection.meta(name: "test", content: "value to \"escape\""),
            HTMLInjection(
                content: #"<meta name="test" content="value to &quot;escape&quot;"/>"#,
                target: .head,
                location: .end
            )
        )
    }

    func testInjectionsOfHTMLStyleTagBefore() {
        XCTAssertEqual(
            HTMLInjection.style("background: red;", prepend: true),
            HTMLInjection(
                content: #"<style type="text/css">background: red;</style>"#,
                target: .head,
                location: .start
            )
        )
    }

    func testInjectionsOfHTMLStyleTagAfter() {
        XCTAssertEqual(
            HTMLInjection.style("background: red;", prepend: false),
            HTMLInjection(
                content: #"<style type="text/css">background: red;</style>"#,
                target: .head,
                location: .end
            )
        )
    }
}
