//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing

struct HTMLInjectionTests {
    let html =
        """
        <html lang="en">
            <head><title>Test</title></head>
            <body>
                <p>Body</p>
            </body>
        </html>
        """

    @Test func injectEmptyContent() throws {
        #expect(
            try HTMLInjection(
                content: "",
                target: .body,
                location: .start
            ).inject(in: html) ==
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

    @Test func injectSingleLine() throws {
        #expect(
            try HTMLInjection(
                content: "<p>Injected</p>",
                target: .body,
                location: .start
            ).inject(in: html) ==
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

    @Test func injectMultipleLines() throws {
        #expect(
            try HTMLInjection(
                content:
                """
                <p>
                Injected
                </p>
                """,
                target: .body,
                location: .start
            ).inject(in: html) ==
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

    @Test func injectInStart() throws {
        #expect(
            try HTMLInjection(
                content: "<p>Injected</p>",
                target: .body,
                location: .start
            ).inject(in: html) ==
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

    @Test func injectInEnd() throws {
        #expect(
            try HTMLInjection(
                content: "<p>Injected</p>",
                target: .body,
                location: .end
            ).inject(in: html) ==
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

    @Test func injectInAttributesWithNoAttributes() throws {
        #expect(
            try HTMLInjection(
                content: " attr='injected'",
                target: .body,
                location: .attributes
            ).inject(in: html) ==
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

    @Test func injectInAttributesWithExistingAttributes() throws {
        #expect(
            try HTMLInjection(
                content: " attr='injected'",
                target: .html,
                location: .attributes
            ).inject(in: html) ==
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

    @Test func injectionOfInjectable() throws {
        #expect(
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
            ]).inject(in: html) ==
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

    @Test func injectionsOfHTMLAttribute() {
        #expect(
            HTMLInjection.attribute("test", on: .body, value: "value to \"escape\"") ==
                HTMLInjection(
                    content: #" test="value to &quot;escape&quot;""#,
                    target: .body,
                    location: .attributes
                )
        )
    }

    @Test func injectionsOfDirHTMLAttribute() {
        #expect(
            HTMLInjection.dirAttribute(on: .body, rtl: false) ==
                HTMLInjection(
                    content: #" dir="ltr""#,
                    target: .body,
                    location: .attributes
                )
        )
        #expect(
            HTMLInjection.dirAttribute(on: .body, rtl: true) ==
                HTMLInjection(
                    content: #" dir="rtl""#,
                    target: .body,
                    location: .attributes
                )
        )
    }

    @Test func injectionsOfLangHTMLAttribute() {
        #expect(
            HTMLInjection.langAttribute(on: .body, language: Language("en")) ==
                HTMLInjection(
                    content: #" xml:lang="en""#,
                    target: .body,
                    location: .attributes
                )
        )
        #expect(
            HTMLInjection.langAttribute(on: .html, language: Language("en_us")) ==
                HTMLInjection(
                    content: #" xml:lang="en-US""#,
                    target: .html,
                    location: .attributes
                )
        )
    }

    @Test func injectionsOfStyleHTMLAttribute() {
        #expect(
            HTMLInjection.styleAttribute(on: .body, css: "background: \"red\";") ==
                HTMLInjection(
                    content: #" style="background: &quot;red&quot;;""#,
                    target: .body,
                    location: .attributes
                )
        )
    }

    @Test func injectionsOfStylesheetLinkTagBefore() {
        #expect(
            HTMLInjection.stylesheetLink(href: "path/to/style.css", prepend: true) ==
                HTMLInjection(
                    content: #"<link rel="stylesheet" href="path/to/style.css" type="text/css"/>"#,
                    target: .head,
                    location: .start
                )
        )
    }

    @Test func injectionsOfStylesheetLinkTagAfter() {
        #expect(
            HTMLInjection.stylesheetLink(href: "path/to/style.css", prepend: false) ==
                HTMLInjection(
                    content: #"<link rel="stylesheet" href="path/to/style.css" type="text/css"/>"#,
                    target: .head,
                    location: .end
                )
        )
    }

    @Test func injectionsOfHTMLMetaTag() {
        #expect(
            HTMLInjection.meta(name: "test", content: "value to \"escape\"") ==
                HTMLInjection(
                    content: #"<meta name="test" content="value to &quot;escape&quot;"/>"#,
                    target: .head,
                    location: .end
                )
        )
    }

    @Test func injectionsOfHTMLStyleTagBefore() {
        #expect(
            HTMLInjection.style("background: red;", prepend: true) ==
                HTMLInjection(
                    content: #"<style type="text/css">background: red;</style>"#,
                    target: .head,
                    location: .start
                )
        )
    }

    @Test func injectionsOfHTMLStyleTagAfter() {
        #expect(
            HTMLInjection.style("background: red;", prepend: false) ==
                HTMLInjection(
                    content: #"<style type="text/css">background: red;</style>"#,
                    target: .head,
                    location: .end
                )
        )
    }
}
