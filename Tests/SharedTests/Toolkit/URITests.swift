//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import R2Shared
import XCTest

class URITest: XCTestCase {
    func testCreateFromInvalidUrl() {
        XCTAssertNil(URI(string: ""))
        XCTAssertNil(URI(string: "     "))
        XCTAssertNil(URI(string: "invalid character"))

        XCTAssertNil(AbsoluteURL(string: " "))
        XCTAssertNil(AbsoluteURL(string: "invalid character"))

        XCTAssertNil(RelativeURL(string: " "))
        XCTAssertNil(RelativeURL(string: "invalid character"))
    }

    func testCreateFromRelativePath() {
        XCTAssertEqual(.relativeURL(RelativeURL(string: "/foo/bar")!), URI(string: "/foo/bar"))
        XCTAssertEqual(.relativeURL(RelativeURL(string: "foo/bar")!), URI(string: "foo/bar"))
        XCTAssertEqual(.relativeURL(RelativeURL(string: "../bar")!), URI(string: "../bar"))

        // Special characters valid in a path.
        XCTAssertEqual(RelativeURL(string: "$&+,/=@")?.string, "$&+,/=@")

        // Used in the EPUB parser
        let url = URI(string: "#")
        XCTAssertNotNil(url?.relativeURL)
    }

    func testCreateFromLegacyHref() {
        XCTAssertEqual(URI(legacyHref: "dir/chapter.xhtml"), .relativeURL(RelativeURL(string: "dir/chapter.xhtml")!))
        // Starting slash is removed.
        XCTAssertEqual(URI(legacyHref: "/dir/chapter.xhtml"), .relativeURL(RelativeURL(string: "dir/chapter.xhtml")!))
        // Special characters are percent-encoded.
        XCTAssertEqual(URI(legacyHref: "/dir/per%cent.xhtml"), .relativeURL(RelativeURL(string: "dir/per%25cent.xhtml")!))
        XCTAssertEqual(URI(legacyHref: "/barré.xhtml"), .relativeURL(RelativeURL(string: "barr%C3%A9.xhtml")!))
        XCTAssertEqual(URI(legacyHref: "/spa ce.xhtml"), .relativeURL(RelativeURL(string: "spa%20ce.xhtml")!))
        // We assume that a relative path is percent-decoded.
        XCTAssertEqual(URI(legacyHref: "/spa%20ce.xhtml"), .relativeURL(RelativeURL(string: "spa%2520ce.xhtml")!))
        // Some special characters are authorized in a path.
        XCTAssertEqual(URI(legacyHref: "/$&+,/=@"), .relativeURL(RelativeURL(string: "$&+,/=@")!))
        // Valid absolute URL are left untouched.
        XCTAssertEqual(
            URI(legacyHref: "http://domain.com/a%20book?page=3"),
            .absoluteURL(AbsoluteURL(string: "http://domain.com/a%20book?page=3")!)
        )
    }

    func testCreateFromFragmentOnly() {
        XCTAssertEqual(URI(string: "#fragment"), .relativeURL(RelativeURL(url: URL(string: "#fragment")!)!))
    }

    func testCreateFromQueryOnly() {
        XCTAssertEqual(URI(string: "?query=param"), .relativeURL(RelativeURL(url: URL(string: "?query=param")!)!))
    }

    func testCreateFromAbsoluteURL() {
        XCTAssertEqual(URI(string: "http://example.com/foo"), .absoluteURL(AbsoluteURL(url: URL(string: "http://example.com/foo")!)!))
    }

    func testString() {
        XCTAssertEqual("foo/bar?query#fragment", URI(string: "foo/bar?query#fragment")?.string)
        XCTAssertEqual("http://example.com/foo/bar?query#fragment", URI(string: "http://example.com/foo/bar?query#fragment")?.string)
        XCTAssertEqual("file:///foo/bar?query#fragment", URI(string: "file:///foo/bar?query#fragment")?.string)
    }

    func testScheme() {
        XCTAssertEqual(.file, URI(string: "FILE:///foo/bar")?.absoluteURL?.scheme)
        XCTAssertEqual(.file, URI(string: "file:///foo/bar")?.absoluteURL?.scheme)
        XCTAssertEqual(.http, URI(string: "http://example.com/foo")?.absoluteURL?.scheme)
        XCTAssertEqual(.https, URI(string: "https://example.com/foo")?.absoluteURL?.scheme)
    }

    func testSchemeType() {
        XCTAssertEqual(URI(string: "file:///foo/bar")?.absoluteURL?.isFile, true)
        XCTAssertEqual(URI(string: "file:///foo/bar")?.absoluteURL?.isHTTP, false)
        XCTAssertEqual(URI(string: "http://example.com/foo")?.absoluteURL?.isFile, false)
        XCTAssertEqual(URI(string: "http://example.com/foo")?.absoluteURL?.isHTTP, true)
        XCTAssertEqual(URI(string: "https://example.com/foo")?.absoluteURL?.isHTTP, true)
    }

    func testResolveHTTPURL() {
        var base = URI(string: "http://example.com/foo/bar")!
        XCTAssertEqual(base.resolve(URI(string: "quz/baz")!)!, URI(string: "http://example.com/foo/quz/baz")!)
        XCTAssertEqual(base.resolve(URI(string: "../quz/baz")!)!, URI(string: "http://example.com/quz/baz")!)
        XCTAssertEqual(base.resolve(URI(string: "/quz/baz")!)!, URI(string: "http://example.com/quz/baz")!)
        XCTAssertEqual(base.resolve(URI(string: "#fragment")!)!, URI(string: "http://example.com/foo/bar#fragment")!)
        XCTAssertEqual(base.resolve(URI(string: "file:///foo/bar")!)!, URI(string: "file:///foo/bar")!)

        // With trailing slash
        base = URI(string: "http://example.com/foo/bar/")!
        XCTAssertEqual(base.resolve(URI(string: "quz/baz")!)!, URI(string: "http://example.com/foo/bar/quz/baz")!)
        XCTAssertEqual(base.resolve(URI(string: "../quz/baz")!)!, URI(string: "http://example.com/foo/quz/baz")!)
    }

    func testResolveFileURL() {
        var base = URI(string: "file:///root/foo/bar")!
        XCTAssertEqual(base.resolve(URI(string: "quz")!)!, URI(string: "file:///root/foo/quz")!)
        XCTAssertEqual(base.resolve(URI(string: "quz/baz")!)!, URI(string: "file:///root/foo/quz/baz")!)
        XCTAssertEqual(base.resolve(URI(string: "../quz")!)!, URI(string: "file:///root/quz")!)

        // With trailing slash
        base = URI(string: "file:///root/foo/bar/")!
        XCTAssertEqual(base.resolve(URI(string: "quz/baz")!)!, URI(string: "file:///root/foo/bar/quz/baz")!)
        XCTAssertEqual(base.resolve(URI(string: "../quz")!)!, URI(string: "file:///root/foo/quz")!)
    }

    func testResolveTwoRelativeURLs() {
        var base = URI(string: "foo/bar")!
        XCTAssertEqual(base.resolve(URI(string: "quz/baz")!)!, URI(string: "foo/quz/baz")!)
        XCTAssertEqual(base.resolve(URI(string: "../quz/baz")!)!, URI(string: "quz/baz")!)
        XCTAssertEqual(base.resolve(URI(string: "/quz/baz")!)!, URI(string: "/quz/baz")!)
        XCTAssertEqual(base.resolve(URI(string: "#fragment")!)!, URI(string: "foo/bar#fragment")!)
        XCTAssertEqual(base.resolve(URI(string: "http://example.com/foo/bar")!)!, URI(string: "http://example.com/foo/bar")!)

        // With trailing slash
        base = URI(string: "foo/bar/")!
        XCTAssertEqual(base.resolve(URI(string: "quz/baz")!)!, URI(string: "foo/bar/quz/baz")!)
        XCTAssertEqual(base.resolve(URI(string: "../quz/baz")!)!, URI(string: "foo/quz/baz")!)

        // With starting slash
        base = URI(string: "/foo/bar")!
        XCTAssertEqual(base.resolve(URI(string: "quz/baz")!)!, URI(string: "/foo/quz/baz")!)
        XCTAssertEqual(base.resolve(URI(string: "/quz/baz")!)!, URI(string: "/quz/baz")!)
    }

    func testRelativizeHTTPURL() {
        var base = URI(string: "http://example.com/foo")!
        XCTAssertEqual(base.relativize(URI(string: "http://example.com/foo/quz/baz")!)!, URI(string: "quz/baz")!)
        XCTAssertEqual(base.relativize(URI(string: "http://example.com/foo#fragment")!)!, URI(string: "#fragment")!)

        // With trailing slash
        base = URI(string: "http://example.com/foo/")!
        XCTAssertEqual(base.relativize(URI(string: "http://example.com/foo/quz/baz")!)!, URI(string: "quz/baz")!)
    }

    func testRelativizeFileURL() {
        var base = URI(string: "file:///root/foo")!
        XCTAssertEqual(base.relativize(URI(string: "file:///root/foo/quz/baz")!)!, URI(string: "quz/baz")!)
        XCTAssertEqual(base.relativize(URI(string: "http://example.com/foo/bar")!)!, URI(string: "http://example.com/foo/bar")!)

        // With trailing slash
        base = URI(string: "file:///root/foo/")!
        XCTAssertEqual(base.relativize(URI(string: "file:///root/foo/quz/baz")!)!, URI(string: "quz/baz")!)
    }

    func testRelativizeTwoRelativeURLs() {
        var base = URI(string: "foo")!
        XCTAssertEqual(base.relativize(URI(string: "foo/quz/baz")!)!, URI(string: "quz/baz")!)
        XCTAssertEqual(base.relativize(URI(string: "quz/baz")!)!, URI(string: "quz/baz")!)
        XCTAssertEqual(base.relativize(URI(string: "/quz/baz")!)!, URI(string: "/quz/baz")!)
        XCTAssertEqual(base.relativize(URI(string: "foo#fragment")!)!, URI(string: "#fragment")!)
        XCTAssertEqual(base.relativize(URI(string: "http://example.com/foo/bar")!)!, URI(string: "http://example.com/foo/bar")!)

        // With trailing slash
        base = URI(string: "foo/")!
        XCTAssertEqual(base.relativize(URI(string: "foo/quz/baz")!)!, URI(string: "quz/baz")!)

        // With starting slash
        base = URI(string: "/foo")!
        XCTAssertEqual(base.relativize(URI(string: "/foo/quz/baz")!)!, URI(string: "quz/baz")!)
        XCTAssertEqual(base.relativize(URI(string: "/quz/baz")!)!, URI(string: "/quz/baz")!)
    }

    func testGetFirstQueryParameterNamedX() throws {
        let uri = try XCTUnwrap(URI(string: "foo?query=param&fruit=banana&query=other&empty"))
        let query = uri.url.query

        XCTAssertEqual(query.first(named: "query"), "param")
        XCTAssertEqual(query.first(named: "fruit"), "banana")
        XCTAssertNil(query.first(named: "empty"))
        XCTAssertNil(query.first(named: "not-found"))
    }

    func testGetAllQueryParametersNamedX() throws {
        let uri = try XCTUnwrap(URI(string: "foo?query=param&fruit=banana&query=other&empty"))
        let query = uri.url.query

        XCTAssertEqual(query.all(named: "query"), ["param", "other"])
        XCTAssertEqual(query.all(named: "fruit"), ["banana"])
        XCTAssertEqual(query.all(named: "empty"), [])
        XCTAssertEqual(query.all(named: "not-found"), [])
    }

    func testQueryParameterArePercentDecoded() throws {
        let uri = try XCTUnwrap(URI(string: "foo?query=hello%20world"))
        let query = uri.url.query

        XCTAssertEqual(query.first(named: "query"), "hello world")
    }
}
