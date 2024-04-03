//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Navigator
import R2Shared
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

    func testLocateStart() {
        let html =
            """
            <html>
               <head><title>Test</title></head>
               <body>📍
                   <p>Body</p>
               </body>
            </html>
            """
        let target = html.firstIndex(of: "📍")!

        XCTAssertEqual(body.locate(.start, in: html), target)
    }

    func testLocateStartIsCaseInsensitive() {
        let html =
            """
            <html>
               <head><title>Test</title></head>
               <BODY>📍
                   <p>Body</p>
               </BODY>
            </html>
            """
        let target = html.firstIndex(of: "📍")!

        XCTAssertEqual(body.locate(.start, in: html), target)
    }

    func testLocateStartIgnoresAttributesAndNewlines() {
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
        let target = html.firstIndex(of: "📍")!

        XCTAssertEqual(body.locate(.start, in: html), target)
    }

    func testLocateEnd() {
        let html =
            """
            <html>
               <head><title>Test</title></head>
               <body>
                   <p>Body</p>
               📍</body>
            </html>
            """
        let target = html.firstIndex(of: "📍")
            .map { html.index($0, offsetBy: 1) }!

        XCTAssertEqual(body.locate(.end, in: html), target)
    }

    func testLocateEndIsCaseInsensitive() {
        let html =
            """
            <html>
               <head><title>Test</title></head>
               <BODY>
                   <p>Body</p>
               📍</BODY>
            </html>
            """
        let target = html.firstIndex(of: "📍")
            .map { html.index($0, offsetBy: 1) }!

        XCTAssertEqual(body.locate(.end, in: html), target)
    }

    func testLocateEndIgnoresWhitespaces() {
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
        let target = html.firstIndex(of: "📍")
            .map { html.index($0, offsetBy: 1) }!

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
}
