//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import XCTest

class HTMLElementTests: XCTestCase {
    let body = HTMLElement.body
    let head = HTMLElement.body

    func testLocateInEmptyDocument() {
        XCTAssertEqual(body.locate(.start, in: ""), nil)
    }

    func testLocateNotFound() {
        let html =
            """
            <html>
                <head><title>Test</title></head>
            </html>
            """

        XCTAssertEqual(body.locate(.start, in: html), nil)
    }

    func testLocateStart() throws {
        let html =
            """
            <html>
               <head><title>Test</title></head>
               <body>📍
                   <p>Body</p>
               </body>
            </html>
            """
        let target = try XCTUnwrap(html.firstIndex(of: "📍"))

        XCTAssertEqual(body.locate(.start, in: html), target)
    }

    func testLocateStartIsCaseInsensitive() throws {
        let html =
            """
            <html>
               <head><title>Test</title></head>
               <BODY>📍
                   <p>Body</p>
               </BODY>
            </html>
            """
        let target = try XCTUnwrap(html.firstIndex(of: "📍"))

        XCTAssertEqual(body.locate(.start, in: html), target)
    }

    func testLocateStartIgnoresAttributesAndNewlines() throws {
        let html =
            """
            <html>
               <head><title>Test</title></head>
               <body  
                  xml:lang="en"  dir="ltr"
                >📍
                   <p>Body</p>
               </body>
            </html>
            """
        let target = try XCTUnwrap(html.firstIndex(of: "📍"))

        XCTAssertEqual(body.locate(.start, in: html), target)
    }

    func testLocateEnd() throws {
        let html =
            """
            <html>
               <head><title>Test</title></head>
               <body>
                   <p>Body</p>
               📍</body>
            </html>
            """
        let target = try XCTUnwrap(html.firstIndex(of: "📍")
            .map { html.index($0, offsetBy: 1) })

        XCTAssertEqual(body.locate(.end, in: html), target)
    }

    func testLocateEndIsCaseInsensitive() throws {
        let html =
            """
            <html>
               <head><title>Test</title></head>
               <BODY>
                   <p>Body</p>
               📍</BODY>
            </html>
            """
        let target = try XCTUnwrap(html.firstIndex(of: "📍")
            .map { html.index($0, offsetBy: 1) })

        XCTAssertEqual(body.locate(.end, in: html), target)
    }

    func testLocateEndIgnoresWhitespaces() throws {
        let html =
            """
            <html>
               <head><title>Test</title></head>
               <body>
                   <p>Body</p>
               📍</body   
                >
            </html>
            """
        let target = try XCTUnwrap(html.firstIndex(of: "📍")
            .map { html.index($0, offsetBy: 1) })

        XCTAssertEqual(body.locate(.end, in: html), target)
    }

    func testLocateAttributes() {
        let html =
            """
            <html>
               <head><title>Test</title></head>
               <body📍>
                   <p>Body</p>
               </body>
            </html>
            """
        let target = html.firstIndex(of: "📍")

        XCTAssertEqual(body.locate(.attributes, in: html), target)
    }

    func testLocateAttributesIsCaseInsensitive() {
        let html =
            """
            <html>
               <head><title>Test</title></head>
               <BODY📍>
                   <p>Body</p>
               </BODY>
            </html>
            """
        let target = html.firstIndex(of: "📍")

        XCTAssertEqual(body.locate(.attributes, in: html), target)
    }

    func testLocateAttributesWithExistingAttributesAndNewlines() {
        let html =
            """
            <html>
               <head><title>Test</title></head>
               <body📍 dir="ltr"
                    xml:lang="en">
                   <p>Body</p>
               </body>
            </html>
            """
        let target = html.firstIndex(of: "📍")

        XCTAssertEqual(body.locate(.attributes, in: html), target)
    }

    // MARK: - hasAttribute(anyOf:in:)

    func testHasAttributeReturnsTrueForLang() {
        let html = #"<html lang="fr"><body></body></html>"#
        XCTAssertTrue(HTMLElement.html.hasAttribute(anyOf: ["xml:lang", "lang"], in: html))
    }

    func testHasAttributeReturnsTrueForXmlLang() {
        let html = #"<html xml:lang="fr"><body></body></html>"#
        XCTAssertTrue(HTMLElement.html.hasAttribute(anyOf: ["xml:lang", "lang"], in: html))
    }

    func testHasAttributeReturnsTrueWhenNotFirstAttribute() {
        let html = #"<html xmlns="http://www.w3.org/1999/xhtml" class="foo" lang="fr"><body></body></html>"#
        XCTAssertTrue(HTMLElement.html.hasAttribute(anyOf: ["xml:lang", "lang"], in: html))
    }

    func testHasAttributeReturnsFalseWhenAbsent() {
        let html = #"<html xmlns="http://www.w3.org/1999/xhtml"><body></body></html>"#
        XCTAssertFalse(HTMLElement.html.hasAttribute(anyOf: ["xml:lang", "lang"], in: html))
    }

    func testHasAttributeReturnsFalseForWrongElement() {
        let html = #"<html><body lang="fr"></body></html>"#
        XCTAssertFalse(HTMLElement.html.hasAttribute(anyOf: ["xml:lang", "lang"], in: html))
    }

    func testHasAttributeIsCaseInsensitive() {
        let html = #"<HTML LANG="fr"><body></body></HTML>"#
        XCTAssertTrue(HTMLElement.html.hasAttribute(anyOf: ["lang"], in: html))
    }

    func testHasAttributeHandlesMultilineTag() {
        let html = "<html\n  xmlns=\"http://www.w3.org/1999/xhtml\"\n  lang=\"fr\">\n<body></body></html>"
        XCTAssertTrue(HTMLElement.html.hasAttribute(anyOf: ["lang"], in: html))
    }

    // MARK: - attribute(firstOf:in:)

    func testAttributeReturnsLangValue() {
        let html = #"<html lang="fr"><body></body></html>"#
        XCTAssertEqual(HTMLElement.html.attribute(firstOf: ["xml:lang", "lang"], in: html), "fr")
    }

    func testAttributePrefersXmlLangOverLang() {
        let html = #"<html xml:lang="de" lang="fr"><body></body></html>"#
        XCTAssertEqual(HTMLElement.html.attribute(firstOf: ["xml:lang", "lang"], in: html), "de")
    }

    func testAttributeFallsBackToLang() {
        let html = #"<html lang="fr"><body></body></html>"#
        XCTAssertEqual(HTMLElement.html.attribute(firstOf: ["xml:lang", "lang"], in: html), "fr")
    }

    func testAttributeReturnsNilWhenAbsent() {
        let html = #"<html xmlns="http://www.w3.org/1999/xhtml"><body></body></html>"#
        XCTAssertNil(HTMLElement.html.attribute(firstOf: ["xml:lang", "lang"], in: html))
    }

    func testAttributeReturnsNilForEmptyValue() {
        let html = #"<html lang=""><body></body></html>"#
        XCTAssertNil(HTMLElement.html.attribute(firstOf: ["xml:lang", "lang"], in: html))
    }

    func testAttributeScopedToCorrectElement() {
        let html = #"<html><body lang="fr"></body></html>"#
        XCTAssertNil(HTMLElement.html.attribute(firstOf: ["lang"], in: html))
        XCTAssertEqual(HTMLElement.body.attribute(firstOf: ["lang"], in: html), "fr")
    }

    func testAttributeHandlesSpacesAroundEquals() {
        let html = #"<html lang = "fr"><body></body></html>"#
        XCTAssertEqual(HTMLElement.html.attribute(firstOf: ["lang"], in: html), "fr")
    }
}
