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

        XCTAssertNil(AnyAbsoluteURL(string: " "))
        XCTAssertNil(AnyAbsoluteURL(string: "invalid character"))

        XCTAssertNil(RelativeURL(string: " "))
        XCTAssertNil(RelativeURL(string: "invalid character"))
    }

    func testCreateFromRelativePath() {
        XCTAssertEqual(.relative(RelativeURL(string: "/foo/bar")!), AnyURL(string: "/foo/bar"))
        XCTAssertEqual(.relative(RelativeURL(string: "foo/bar")!), AnyURL(string: "foo/bar"))
        XCTAssertEqual(.relative(RelativeURL(string: "../bar")!), AnyURL(string: "../bar"))

        // Special characters valid in a path
        XCTAssertEqual(RelativeURL(string: "$&+,/=@")?.string, "$&+,/=@")

        // Used in the EPUB parser
        let url = AnyURL(string: "#")
        XCTAssertNotNil(url?.relativeURL)
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
            .absolute(AnyAbsoluteURL(string: "http://domain.com/a%20book?page=3")!)
        )
    }

    func testCreateFromFragmentOnly() {
        XCTAssertEqual(AnyURL(string: "#fragment"), .relative(RelativeURL(url: URL(string: "#fragment")!)!))
    }

    func testCreateFromQueryOnly() {
        XCTAssertEqual(AnyURL(string: "?query=param"), .relative(RelativeURL(url: URL(string: "?query=param")!)!))
    }

    func testCreateFromAbsoluteURL() {
        XCTAssertEqual(AnyURL(string: "http://example.com/foo"), .absolute(AnyAbsoluteURL(url: URL(string: "http://example.com/foo")!)!))
    }

    func testString() {
        XCTAssertEqual("foo/bar?query#fragment", AnyURL(string: "foo/bar?query#fragment")?.string)
        XCTAssertEqual("http://example.com/foo/bar?query#fragment", AnyURL(string: "http://example.com/foo/bar?query#fragment")?.string)
        XCTAssertEqual("file:///foo/bar", AnyURL(string: "file:///foo/bar?query#fragment")?.string)
    }

    func testPath() {
        XCTAssertEqual(AnyURL(string: "foo/bar?query#fragment")?.path, "foo/bar")
        XCTAssertEqual(AnyURL(string: "http://example.com/foo/bar/")?.path, "/foo/bar/")
        XCTAssertEqual(AnyURL(string: "http://example.com/foo/bar?query#fragment")?.path, "/foo/bar")
        XCTAssertEqual(AnyURL(string: "file:///foo/bar/")?.path, "/foo/bar/")
        XCTAssertEqual(AnyURL(string: "file:///foo/bar?query#fragment")?.path, "/foo/bar")
    }

    func testPathFromEmptyRelativeUrl() {
        XCTAssertNil(AnyURL(string: "#fragment")!.path)
    }

    func testPathIsPercentDecoded() {
        XCTAssertEqual(AnyURL(string: "foo/%25bar%20quz")?.path, "foo/%bar quz")
        XCTAssertEqual(AnyURL(string: "http://example.com/foo/%25bar%20quz")?.path, "/foo/%bar quz")
    }

    func testScheme() {
        XCTAssertEqual(.file, AnyURL(string: "FILE:///foo/bar")?.absoluteURL?.scheme)
        XCTAssertEqual(.file, AnyURL(string: "file:///foo/bar")?.absoluteURL?.scheme)
        XCTAssertEqual(.http, AnyURL(string: "http://example.com/foo")?.absoluteURL?.scheme)
        XCTAssertEqual(.https, AnyURL(string: "https://example.com/foo")?.absoluteURL?.scheme)
    }

//    func testSchemeType() {
//        XCTAssertEqual(AnyURL(string: "file:///foo/bar")?.absoluteURL?.isFile, true)
//        XCTAssertEqual(AnyURL(string: "file:///foo/bar")?.absoluteURL?.isHTTP, false)
//        XCTAssertEqual(AnyURL(string: "http://example.com/foo")?.absoluteURL?.isFile, false)
//        XCTAssertEqual(AnyURL(string: "http://example.com/foo")?.absoluteURL?.isHTTP, true)
//        XCTAssertEqual(AnyURL(string: "https://example.com/foo")?.absoluteURL?.isHTTP, true)
//    }

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
        var base = AnyURL(string: "foo/bar")!
        XCTAssertEqual(base.resolve(AnyURL(string: "quz/baz")!)!, AnyURL(string: "foo/quz/baz")!)
        XCTAssertEqual(base.resolve(AnyURL(string: "../quz/baz")!)!, AnyURL(string: "quz/baz")!)
        XCTAssertEqual(base.resolve(AnyURL(string: "/quz/baz")!)!, AnyURL(string: "/quz/baz")!)
        XCTAssertEqual(base.resolve(AnyURL(string: "#fragment")!)!, AnyURL(string: "foo/bar#fragment")!)
        XCTAssertEqual(base.resolve(AnyURL(string: "http://example.com/foo/bar")!)!, AnyURL(string: "http://example.com/foo/bar")!)

        // With trailing slash
        base = AnyURL(string: "foo/bar/")!
        XCTAssertEqual(base.resolve(AnyURL(string: "quz/baz")!)!, AnyURL(string: "foo/bar/quz/baz")!)
        XCTAssertEqual(base.resolve(AnyURL(string: "../quz/baz")!)!, AnyURL(string: "foo/quz/baz")!)

        // With starting slash
        base = AnyURL(string: "/foo/bar")!
        XCTAssertEqual(base.resolve(AnyURL(string: "quz/baz")!)!, AnyURL(string: "/foo/quz/baz")!)
        XCTAssertEqual(base.resolve(AnyURL(string: "/quz/baz")!)!, AnyURL(string: "/quz/baz")!)
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

    func testGetFirstQueryParameterNamedX() throws {
        let query = try XCTUnwrap(AnyURL(string: "foo?query=param&fruit=banana&query=other&empty")).query

        XCTAssertEqual(query.first(named: "query"), "param")
        XCTAssertEqual(query.first(named: "fruit"), "banana")
        XCTAssertNil(query.first(named: "empty"))
        XCTAssertNil(query.first(named: "not-found"))
    }

    func testGetAllQueryParametersNamedX() throws {
        let query = try XCTUnwrap(AnyURL(string: "foo?query=param&fruit=banana&query=other&empty")).query

        XCTAssertEqual(query.all(named: "query"), ["param", "other"])
        XCTAssertEqual(query.all(named: "fruit"), ["banana"])
        XCTAssertEqual(query.all(named: "empty"), [])
        XCTAssertEqual(query.all(named: "not-found"), [])
    }

    func testQueryParameterArePercentDecoded() throws {
        let query = try XCTUnwrap(AnyURL(string: "foo?query=hello%20world")).query
        XCTAssertEqual(query.first(named: "query"), "hello world")
    }
}
