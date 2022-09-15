//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest
import R2Shared
@testable import R2Navigator

class HTMLInjectionTests: XCTestCase {

    let html =
        """
        <html>
            <head><title>Test</title></head>
            <body>
                <p>Body</p>
            </body>
        </html>
        """

    func testInjectEmptyContent() {
        XCTAssertEqual(
            HTMLInjection(
                content: "",
                target: .body,
                location: .start
            ).inject(in: html),
            """
            <html>
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
            HTMLInjection(
                content: "<p>Injected</p>",
                target: .body,
                location: .start
            ).inject(in: html),
            """
            <html>
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
            HTMLInjection(
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
            <html>
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
            HTMLInjection(
                content: "<p>Injected</p>",
                target: .body,
                location: .start
            ).inject(in: html),
            """
            <html>
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
            HTMLInjection(
                content: "<p>Injected</p>",
                target: .body,
                location: .end
            ).inject(in: html),
            """
            <html>
                <head><title>Test</title></head>
                <body>
                    <p>Body</p>
                <p>Injected</p></body>
            </html>
            """
        )
    }

    func testInjectInAttributes() {
        XCTAssertEqual(
            HTMLInjection(
                content: " attr='injected'",
                target: .body,
                location: .attributes
            ).inject(in: html),
            """
            <html>
                <head><title>Test</title></head>
                <body attr='injected'>
                    <p>Body</p>
                </body>
            </html>
            """
        )
    }

    func testInjectionOfInjectable() {
        XCTAssertEqual(
            InjectableFixture(injects: [
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
            <html>
                <head><title>Test</title><meta/></head>
                <body attr1='value1' attr2='value2'><p>Start2</p><p>Start1</p>
                    <p>Body</p>
                <p>End1</p><p>End2</p></body>
            </html>
            """
        )
    }

    struct InjectableFixture: HTMLInjectable {
        let injects: [HTMLInjection]

        func injections() -> [HTMLInjection] {
            injects
        }
    }
}
