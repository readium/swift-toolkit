//
//  PublicationParserTests.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 30/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Streamer

class PublicationParserTests: XCTestCase {

    func testNormalizeHREF() {
        XCTAssertEqual(normalize(base: "", href: "foo/bar.txt"), "/foo/bar.txt")
        XCTAssertEqual(normalize(base: "", href: "/foo/bar.txt"), "/foo/bar.txt")
        XCTAssertEqual(normalize(base: "/", href: "http://absolute.com/foo/bar.txt"), "http://absolute.com/foo/bar.txt")
        XCTAssertEqual(normalize(base: "/", href: "foo/bar.txt"), "/foo/bar.txt")
        XCTAssertEqual(normalize(base: "/", href: "/foo/bar.txt"), "/foo/bar.txt")
        XCTAssertEqual(normalize(base: "/", href: "http://absolute.com/foo/bar.txt"), "http://absolute.com/foo/bar.txt")
        XCTAssertEqual(normalize(base: "/file.txt", href: "foo/bar.txt"), "/foo/bar.txt")
        XCTAssertEqual(normalize(base: "/file.txt", href: "/foo/bar.txt"), "/foo/bar.txt")
        XCTAssertEqual(normalize(base: "/file.txt", href: "http://absolute.com/foo/bar.txt"), "http://absolute.com/foo/bar.txt")
        XCTAssertEqual(normalize(base: "/folder/", href: "foo/bar.txt"), "/foo/bar.txt")
        XCTAssertEqual(normalize(base: "/folder/", href: "/foo/bar.txt"), "/foo/bar.txt")
        XCTAssertEqual(normalize(base: "/folder/", href: "http://absolute.com/foo/bar.txt"), "http://absolute.com/foo/bar.txt")
    }

}
