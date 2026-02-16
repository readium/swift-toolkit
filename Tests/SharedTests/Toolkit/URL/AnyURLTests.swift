//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import XCTest

class AnyURLTests: XCTestCase {
    func testEquality() throws {
        XCTAssertEqual(
            AnyURL(string: "opds://domain.com"),
            AnyURL(string: "opds://domain.com")
        )
        XCTAssertNotEqual(
            try XCTUnwrap(AnyURL(string: "opds://domain.com")),
            try XCTUnwrap(AnyURL(string: "https://domain.com"))
        )

        XCTAssertEqual(
            AnyURL(string: "dir/file"),
            AnyURL(string: "dir/file")
        )
        XCTAssertNotEqual(
            try XCTUnwrap(AnyURL(string: "dir/file")),
            try XCTUnwrap(AnyURL(string: "dir/file#fragment"))
        )
    }

    func testCreateFromInvalidUrl() {
        XCTAssertNil(AnyURL(string: ""))
        XCTAssertNil(AnyURL(string: "     "))
        XCTAssertNil(AnyURL(string: "invalid character"))
    }

    func testCreateFromRelativePath() throws {
        XCTAssertEqual(AnyURL(string: "/foo/bar"), try .relative(XCTUnwrap(RelativeURL(string: "/foo/bar"))))
        XCTAssertEqual(AnyURL(string: "foo/bar"), try .relative(XCTUnwrap(RelativeURL(string: "foo/bar"))))
        XCTAssertEqual(AnyURL(string: "../bar"), try .relative(XCTUnwrap(RelativeURL(string: "../bar"))))
    }

    func testCreateFromAbsoluteURLs() throws {
        XCTAssertEqual(AnyURL(string: "file:///foo/bar"), try .absolute(XCTUnwrap(FileURL(string: "file:///foo/bar"))))
        XCTAssertEqual(AnyURL(string: "http://host/foo/bar"), try .absolute(XCTUnwrap(HTTPURL(string: "http://host/foo/bar"))))
        XCTAssertEqual(AnyURL(string: "opds://host/foo/bar"), try .absolute(XCTUnwrap(UnknownAbsoluteURL(string: "opds://host/foo/bar"))))
    }

    func testCreateFromLegacyHREF() throws {
        XCTAssertEqual(AnyURL(legacyHREF: "dir/chapter.xhtml"), try .relative(XCTUnwrap(RelativeURL(string: "dir/chapter.xhtml"))))
        // Starting slash is removed.
        XCTAssertEqual(AnyURL(legacyHREF: "/dir/chapter.xhtml"), try .relative(XCTUnwrap(RelativeURL(string: "dir/chapter.xhtml"))))
        // Special characters are percent-encoded.
        XCTAssertEqual(AnyURL(legacyHREF: "/dir/per%cent.xhtml"), try .relative(XCTUnwrap(RelativeURL(string: "dir/per%25cent.xhtml"))))
        XCTAssertEqual(AnyURL(legacyHREF: "/barré.xhtml"), try .relative(XCTUnwrap(RelativeURL(string: "barr%C3%A9.xhtml"))))
        XCTAssertEqual(AnyURL(legacyHREF: "/spa ce.xhtml"), try .relative(XCTUnwrap(RelativeURL(string: "spa%20ce.xhtml"))))
        // We assume that a relative path is percent-decoded.
        XCTAssertEqual(AnyURL(legacyHREF: "/spa%20ce.xhtml"), try .relative(XCTUnwrap(RelativeURL(string: "spa%2520ce.xhtml"))))
        // Some special characters are authorized in a path.
        XCTAssertEqual(AnyURL(legacyHREF: "/$&+,/=@"), try .relative(XCTUnwrap(RelativeURL(string: "$&+,/=@"))))
        // Valid absolute URL are left untouched.
        XCTAssertEqual(
            AnyURL(legacyHREF: "http://domain.com/a%20book?page=3"),
            try .absolute(XCTUnwrap(HTTPURL(string: "http://domain.com/a%20book?page=3")))
        )
    }

    func testResolveHTTPURL() throws {
        var base = try XCTUnwrap(AnyURL(string: "http://example.com/foo/bar"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(AnyURL(string: "quz/baz")))?.string, "http://example.com/foo/quz/baz")
        XCTAssertEqual(try base.resolve(XCTUnwrap(AnyURL(string: "../quz/baz")))?.string, "http://example.com/quz/baz")
        XCTAssertEqual(try base.resolve(XCTUnwrap(AnyURL(string: "/quz/baz")))?.string, "http://example.com/quz/baz")
        XCTAssertEqual(try base.resolve(XCTUnwrap(AnyURL(string: "#fragment")))?.string, "http://example.com/foo/bar#fragment")
        XCTAssertEqual(try base.resolve(XCTUnwrap(AnyURL(string: "file:///foo/bar")))?.string, "file:///foo/bar")

        // With trailing slash
        base = try XCTUnwrap(AnyURL(string: "http://example.com/foo/bar/"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(AnyURL(string: "quz/baz")))?.string, "http://example.com/foo/bar/quz/baz")
        XCTAssertEqual(try base.resolve(XCTUnwrap(AnyURL(string: "../quz/baz")))?.string, "http://example.com/foo/quz/baz")
    }

    func testResolveFileURL() throws {
        var base = try XCTUnwrap(AnyURL(string: "file:///root/foo/bar"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(AnyURL(string: "quz")))?.string, "file:///root/foo/quz")
        XCTAssertEqual(try base.resolve(XCTUnwrap(AnyURL(string: "quz/baz")))?.string, "file:///root/foo/quz/baz")
        XCTAssertEqual(try base.resolve(XCTUnwrap(AnyURL(string: "../quz")))?.string, "file:///root/quz")

        // With trailing slash
        base = try XCTUnwrap(AnyURL(string: "file:///root/foo/bar/"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(AnyURL(string: "quz/baz")))?.string, "file:///root/foo/bar/quz/baz")
        XCTAssertEqual(try base.resolve(XCTUnwrap(AnyURL(string: "../quz")))?.string, "file:///root/foo/quz")
    }

    func testResolveTwoRelativeURLs() throws {
        var base = try XCTUnwrap(RelativeURL(string: "foo/bar"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(RelativeURL(string: "quz/baz"))), RelativeURL(string: "foo/quz/baz"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(RelativeURL(string: "../quz/baz"))), RelativeURL(string: "quz/baz"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(RelativeURL(string: "/quz/baz"))), RelativeURL(string: "/quz/baz"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(RelativeURL(string: "#fragment"))), RelativeURL(string: "foo/bar#fragment"))

        // With trailing slash
        base = try XCTUnwrap(RelativeURL(string: "foo/bar/"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(RelativeURL(string: "quz/baz"))), RelativeURL(string: "foo/bar/quz/baz"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(RelativeURL(string: "../quz/baz"))), RelativeURL(string: "foo/quz/baz"))

        // With starting slash
        base = try XCTUnwrap(RelativeURL(string: "/foo/bar"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(RelativeURL(string: "quz/baz"))), RelativeURL(string: "/foo/quz/baz"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(RelativeURL(string: "/quz/baz"))), RelativeURL(string: "/quz/baz"))
    }

    func testRelativizeHTTPURL() throws {
        var base = try XCTUnwrap(AnyURL(string: "http://example.com/foo"))
        XCTAssertEqual(try base.relativize(XCTUnwrap(AnyURL(string: "http://example.com/foo/quz/baz")))?.string, "quz/baz")
        XCTAssertEqual(try base.relativize(XCTUnwrap(AnyURL(string: "http://example.com/foo#fragment")))?.string, "#fragment")

        // With trailing slash
        base = try XCTUnwrap(AnyURL(string: "http://example.com/foo/"))
        XCTAssertEqual(try base.relativize(XCTUnwrap(AnyURL(string: "http://example.com/foo/quz/baz")))?.string, "quz/baz")
    }

    func testRelativizeFileURL() throws {
        var base = try XCTUnwrap(AnyURL(string: "file:///root/foo"))
        XCTAssertEqual(try base.relativize(XCTUnwrap(AnyURL(string: "file:///root/foo/quz/baz")))?.string, "quz/baz")
        XCTAssertNil(try base.relativize(XCTUnwrap(AnyURL(string: "http://example.com/foo/bar"))))

        // With trailing slash
        base = try XCTUnwrap(AnyURL(string: "file:///root/foo/"))
        XCTAssertEqual(try base.relativize(XCTUnwrap(AnyURL(string: "file:///root/foo/quz/baz")))?.string, "quz/baz")
    }

    func testRelativizeTwoRelativeURLs() throws {
        var base = try XCTUnwrap(AnyURL(string: "foo"))
        XCTAssertEqual(try base.relativize(XCTUnwrap(AnyURL(string: "foo/quz/baz")))?.string, "quz/baz")
        XCTAssertEqual(try base.relativize(XCTUnwrap(AnyURL(string: "foo#fragment")))?.string, "#fragment")
        XCTAssertNil(try base.relativize(XCTUnwrap(AnyURL(string: "quz/baz"))))
        XCTAssertNil(try base.relativize(XCTUnwrap(AnyURL(string: "/quz/baz"))))
        XCTAssertNil(try base.relativize(XCTUnwrap(AnyURL(string: "http://example.com/foo/bar"))))

        // With trailing slash
        base = try XCTUnwrap(AnyURL(string: "foo/"))
        XCTAssertEqual(try base.relativize(XCTUnwrap(AnyURL(string: "foo/quz/baz")))?.string, "quz/baz")

        // With starting slash
        base = try XCTUnwrap(AnyURL(string: "/foo"))
        XCTAssertEqual(try base.relativize(XCTUnwrap(AnyURL(string: "/foo/quz/baz")))?.string, "quz/baz")
        XCTAssertNil(try base.relativize(XCTUnwrap(AnyURL(string: "/quz/baz"))))
    }

    func testNormalized() {
        // Scheme is lower case.
        XCTAssertEqual(
            AnyURL(string: "HTTP://example.com")?.normalized.string,
            "http://example.com"
        )

        // Path is percent-decoded.
        XCTAssertEqual(
            AnyURL(string: "HTTP://example.com/c%27est%20valide")?.normalized.string,
            "http://example.com/c'est%20valide"
        )
        XCTAssertEqual(
            AnyURL(string: "c%27est%20valide")?.normalized.string,
            "c'est%20valide"
        )

        // Relative paths are resolved.
        XCTAssertEqual(
            AnyURL(string: "http://example.com/foo/./bar/../baz")?.normalized.string,
            "http://example.com/foo/baz"
        )
        XCTAssertEqual(
            AnyURL(string: "foo/./bar/../baz")?.normalized.string,
            "foo/baz"
        )
        XCTAssertEqual(
            AnyURL(string: "foo/./bar/../../../baz")?.normalized.string,
            "../baz"
        )

        // Trailing slash is kept.
        XCTAssertEqual(
            AnyURL(string: "http://example.com/foo/")?.normalized.string,
            "http://example.com/foo/"
        )
        XCTAssertEqual(
            AnyURL(string: "foo/")?.normalized.string,
            "foo/"
        )

        // The other components are left as-is.
        XCTAssertEqual(
            AnyURL(string: "http://user:password@example.com:443/foo?b=b&a=a#fragment")?.normalized.string,
            "http://user:password@example.com:443/foo?b=b&a=a#fragment"
        )
    }
}
