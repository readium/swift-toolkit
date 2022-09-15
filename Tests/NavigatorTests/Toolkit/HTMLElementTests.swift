//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest
import R2Shared
@testable import R2Navigator

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
        let target = html.firstIndex(of: "📍")!

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
        let target = html.firstIndex(of: "📍")!

        XCTAssertEqual(body.locate(.end, in: html), target)
    }
}
