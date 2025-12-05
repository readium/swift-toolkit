//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class URITemplateTests: XCTestCase {
    func testParameters() {
        XCTAssertEqual(
            URITemplate("/url{?x,hello,y}name{z,y,w}").parameters,
            ["x", "hello", "y", "z", "w"]
        )
    }

    func testParametersWithNoVariables() {
        XCTAssertEqual(URITemplate("/url").parameters, [])
    }

    func testExpandSimpleStringTemplates() {
        XCTAssertEqual(
            URITemplate("/url{x,hello,y}name{z,y,w}").expand(with: [
                "x": "aaa",
                "hello": "Hello, world",
                "y": "b",
                "z": "45",
                "w": "w",
            ]),
            "/urlaaa,Hello,%20world,bname45,b,w"
        )
    }

    func testExpandFormStyleAmpersandSeparatedTemplates() {
        XCTAssertEqual(
            URITemplate("/url{?x,hello,y}name").expand(with: [
                "x": "aaa",
                "hello": "Hello, world",
                "y": "b",
            ]),
            "/url?x=aaa&hello=Hello,%20world&y=bname"
        )
    }

    func testExpandIgnoresExtraParameters() {
        XCTAssertEqual(
            URITemplate("/path{?search}").expand(with: [
                "search": "banana",
                "code": "14",
            ]),
            "/path?search=banana"
        )
    }

    func testExpandWithNoVariables() {
        XCTAssertEqual(
            URITemplate("/path").expand(with: [
                "search": "banana",
            ]),
            "/path"
        )
    }
}
