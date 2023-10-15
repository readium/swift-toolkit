//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import R2Shared
import XCTest

class AnyURLTests: XCTestCase {
    func testCreateFromInvalidUrl() {
        XCTAssertNil(AnyURL(string: ""))
        XCTAssertNil(AnyURL(string: "     "))
        XCTAssertNil(AnyURL(string: "invalid character"))
    }

    func testCreateFromRelativePath() {
        XCTAssertEqual(AnyURL(string: "/foo/bar"), .relative(RelativeURL(string: "/foo/bar")!))
        XCTAssertEqual(AnyURL(string: "foo/bar"), .relative(RelativeURL(string: "foo/bar")!))
        XCTAssertEqual(AnyURL(string: "../bar"), .relative(RelativeURL(string: "../bar")!))
    }

    func testCreateFromAbsoluteURLs() {
        XCTAssertEqual(AnyURL(string: "file:///foo/bar"), .absolute(FileURL(string: "file:///foo/bar")!))
        XCTAssertEqual(AnyURL(string: "http://host/foo/bar"), .absolute(HTTPURL(string: "http://host/foo/bar")!))
        XCTAssertEqual(AnyURL(string: "opds://host/foo/bar"), .absolute(UnknownAbsoluteURL(string: "opds://host/foo/bar")!))
    }

    func testCreateFromLegacyHref() {
        XCTAssertEqual(AnyURL(legacyHref: "dir/chapter.xhtml"), .relative(RelativeURL(string: "dir/chapter.xhtml")!))
        // Starting slash is removed.
        XCTAssertEqual(AnyURL(legacyHref: "/dir/chapter.xhtml"), .relative(RelativeURL(string: "dir/chapter.xhtml")!))
        // Special characters are percent-encoded.
        XCTAssertEqual(AnyURL(legacyHref: "/dir/per%cent.xhtml"), .relative(RelativeURL(string: "dir/per%25cent.xhtml")!))
        XCTAssertEqual(AnyURL(legacyHref: "/barré.xhtml"), .relative(RelativeURL(string: "barr%C3%A9.xhtml")!))
        XCTAssertEqual(AnyURL(legacyHref: "/spa ce.xhtml"), .relative(RelativeURL(string: "spa%20ce.xhtml")!))
        // We assume that a relative path is percent-decoded.
        XCTAssertEqual(AnyURL(legacyHref: "/spa%20ce.xhtml"), .relative(RelativeURL(string: "spa%2520ce.xhtml")!))
        // Some special characters are authorized in a path.
        XCTAssertEqual(AnyURL(legacyHref: "/$&+,/=@"), .relative(RelativeURL(string: "$&+,/=@")!))
        // Valid absolute URL are left untouched.
        XCTAssertEqual(
            AnyURL(legacyHref: "http://domain.com/a%20book?page=3"),
            .absolute(HTTPURL(string: "http://domain.com/a%20book?page=3")!)
        )
    }

    func testResolveHTTPURL() {
        var base = AnyURL(string: "http://example.com/foo/bar")!
        XCTAssertEqual(base.resolve(AnyURL(string: "quz/baz")!)!, AnyURL(string: "http://example.com/foo/quz/baz")!)
        XCTAssertEqual(base.resolve(AnyURL(string: "../quz/baz")!)!, AnyURL(string: "http://example.com/quz/baz")!)
        XCTAssertEqual(base.resolve(AnyURL(string: "/quz/baz")!)!, AnyURL(string: "http://example.com/quz/baz")!)
        XCTAssertEqual(base.resolve(AnyURL(string: "#fragment")!)!, AnyURL(string: "http://example.com/foo/bar#fragment")!)
        XCTAssertNil(base.resolve(AnyURL(string: "file:///foo/bar")!))

        // With trailing slash
        base = AnyURL(string: "http://example.com/foo/bar/")!
        XCTAssertEqual(base.resolve(AnyURL(string: "quz/baz")!)!, AnyURL(string: "http://example.com/foo/bar/quz/baz")!)
        XCTAssertEqual(base.resolve(AnyURL(string: "../quz/baz")!)!, AnyURL(string: "http://example.com/foo/quz/baz")!)
    }

    func testResolveFileURL() {
        var base = AnyURL(string: "file:///root/foo/bar")!
        XCTAssertEqual(base.resolve(AnyURL(string: "quz")!)!, AnyURL(string: "file:///root/foo/quz")!)
        XCTAssertEqual(base.resolve(AnyURL(string: "quz/baz")!)!, AnyURL(string: "file:///root/foo/quz/baz")!)
        XCTAssertEqual(base.resolve(AnyURL(string: "../quz")!)!, AnyURL(string: "file:///root/quz")!)

        // With trailing slash
        base = AnyURL(string: "file:///root/foo/bar/")!
        XCTAssertEqual(base.resolve(AnyURL(string: "quz/baz")!)!, AnyURL(string: "file:///root/foo/bar/quz/baz")!)
        XCTAssertEqual(base.resolve(AnyURL(string: "../quz")!)!, AnyURL(string: "file:///root/foo/quz")!)
    }

    func testResolveTwoRelativeURLs() {
        var base = RelativeURL(string: "foo/bar")!
        XCTAssertEqual(base.resolve(RelativeURL(string: "quz/baz")!)!, RelativeURL(string: "foo/quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "../quz/baz")!)!, RelativeURL(string: "quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "/quz/baz")!)!, RelativeURL(string: "/quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "#fragment")!)!, RelativeURL(string: "foo/bar#fragment")!)

        // With trailing slash
        base = RelativeURL(string: "foo/bar/")!
        XCTAssertEqual(base.resolve(RelativeURL(string: "quz/baz")!)!, RelativeURL(string: "foo/bar/quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "../quz/baz")!)!, RelativeURL(string: "foo/quz/baz")!)

        // With starting slash
        base = RelativeURL(string: "/foo/bar")!
        XCTAssertEqual(base.resolve(RelativeURL(string: "quz/baz")!)!, RelativeURL(string: "/foo/quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "/quz/baz")!)!, RelativeURL(string: "/quz/baz")!)
    }

    func testRelativizeHTTPURL() {
        var base = AnyURL(string: "http://example.com/foo")!
        XCTAssertEqual(base.relativize(AnyURL(string: "http://example.com/foo/quz/baz")!)!, AnyURL(string: "quz/baz")!)
        XCTAssertEqual(base.relativize(AnyURL(string: "http://example.com/foo#fragment")!)!, AnyURL(string: "#fragment")!)

        // With trailing slash
        base = AnyURL(string: "http://example.com/foo/")!
        XCTAssertEqual(base.relativize(AnyURL(string: "http://example.com/foo/quz/baz")!)!, AnyURL(string: "quz/baz")!)
    }

    func testRelativizeFileURL() {
        var base = AnyURL(string: "file:///root/foo")!
        XCTAssertEqual(base.relativize(AnyURL(string: "file:///root/foo/quz/baz")!)!, AnyURL(string: "quz/baz")!)
        XCTAssertNil(base.relativize(AnyURL(string: "http://example.com/foo/bar")!))

        // With trailing slash
        base = AnyURL(string: "file:///root/foo/")!
        XCTAssertEqual(base.relativize(AnyURL(string: "file:///root/foo/quz/baz")!)!, AnyURL(string: "quz/baz")!)
    }

    func testRelativizeTwoRelativeURLs() {
        var base = AnyURL(string: "foo")!
        XCTAssertEqual(base.relativize(AnyURL(string: "foo/quz/baz")!)!, AnyURL(string: "quz/baz")!)
        XCTAssertEqual(base.relativize(AnyURL(string: "foo#fragment")!)!, AnyURL(string: "#fragment")!)
        XCTAssertNil(base.relativize(AnyURL(string: "quz/baz")!))
        XCTAssertNil(base.relativize(AnyURL(string: "/quz/baz")!))
        XCTAssertNil(base.relativize(AnyURL(string: "http://example.com/foo/bar")!))

        // With trailing slash
        base = AnyURL(string: "foo/")!
        XCTAssertEqual(base.relativize(AnyURL(string: "foo/quz/baz")!)!, AnyURL(string: "quz/baz")!)

        // With starting slash
        base = AnyURL(string: "/foo")!
        XCTAssertEqual(base.relativize(AnyURL(string: "/foo/quz/baz")!)!, AnyURL(string: "quz/baz")!)
        XCTAssertNil(base.relativize(AnyURL(string: "/quz/baz")!))
    }
}
