//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import XCTest

class HTTPURLTests: XCTestCase {
    func testEquality() throws {
        XCTAssertEqual(
            HTTPURL(string: "http://domain.com"),
            HTTPURL(string: "http://domain.com")
        )
        XCTAssertNotEqual(
            try XCTUnwrap(HTTPURL(string: "http://domain.com")),
            try XCTUnwrap(HTTPURL(string: "http://domain.com#fragment"))
        )
    }

    // MARK: - URLProtocol

    func testCreateFromURL() throws {
        XCTAssertEqual(try HTTPURL(url: XCTUnwrap(URL(string: "http://domain.com")))?.string, "http://domain.com")
        XCTAssertEqual(try HTTPURL(url: XCTUnwrap(URL(string: "https://domain.com")))?.string, "https://domain.com")

        // Only valid for schemes `http` or `https`.
        XCTAssertNil(try HTTPURL(url: XCTUnwrap(URL(string: "file://domain.com"))))
        XCTAssertNil(try HTTPURL(url: XCTUnwrap(URL(string: "opds://domain.com"))))
    }

    func testCreateFromString() {
        XCTAssertEqual(HTTPURL(string: "http://domain.com")?.string, "http://domain.com")

        // Empty
        XCTAssertNil(HTTPURL(string: "")?.string)
        // Not absolute
        XCTAssertNil(HTTPURL(string: "path"))
        // Only valid for schemes `http` or `https`.
        XCTAssertNil(HTTPURL(string: "file://domain.com"))
        XCTAssertNil(HTTPURL(string: "opds://domain.com"))
    }

    func testURL() {
        XCTAssertEqual(HTTPURL(string: "http://foo/bar?query#fragment")?.url, URL(string: "http://foo/bar?query#fragment"))
    }

    func testString() {
        XCTAssertEqual(HTTPURL(string: "http://foo/bar?query#fragment")?.string, "http://foo/bar?query#fragment")
    }

    func testPath() {
        // Path is percent-decoded.
        XCTAssertEqual(HTTPURL(string: "http://host/foo/bar%20baz")?.path, "/foo/bar baz")
        XCTAssertEqual(HTTPURL(string: "http://host/foo/bar%20baz/")?.path, "/foo/bar baz/")
        XCTAssertEqual(HTTPURL(string: "http://host/foo/bar?query#fragment")?.path, "/foo/bar")
        XCTAssertEqual(HTTPURL(string: "http://host#fragment")?.path, "")
        XCTAssertEqual(HTTPURL(string: "http://host?query")?.path, "")
    }

    func testAppendingPath() throws {
        var base = try XCTUnwrap(HTTPURL(string: "http://foo/bar"))
        XCTAssertEqual(base.appendingPath("", isDirectory: false).string, "http://foo/bar")
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: false).string, "http://foo/bar/baz/quz")
        XCTAssertEqual(base.appendingPath("/baz/quz", isDirectory: false).string, "http://foo/bar/baz/quz")
        // The path is supposed to be decoded
        XCTAssertEqual(base.appendingPath("baz quz", isDirectory: false).string, "http://foo/bar/baz%20quz")
        XCTAssertEqual(base.appendingPath("baz%20quz", isDirectory: false).string, "http://foo/bar/baz%2520quz")
        // Directory
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: true).string, "http://foo/bar/baz/quz/")
        XCTAssertEqual(base.appendingPath("baz/quz/", isDirectory: true).string, "http://foo/bar/baz/quz/")
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: false).string, "http://foo/bar/baz/quz")
        XCTAssertEqual(base.appendingPath("baz/quz/", isDirectory: false).string, "http://foo/bar/baz/quz")

        // With trailing slash.
        base = try XCTUnwrap(HTTPURL(string: "http://foo/bar/"))
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: false).string, "http://foo/bar/baz/quz")
    }

    func testPathSegments() {
        XCTAssertEqual(HTTPURL(string: "http://host/foo")?.pathSegments, ["foo"])
        // Segments are percent-decoded.
        XCTAssertEqual(HTTPURL(string: "http://host/foo/bar%20baz")?.pathSegments, ["foo", "bar baz"])
        XCTAssertEqual(HTTPURL(string: "http://host/foo/bar%20baz/")?.pathSegments, ["foo", "bar baz"])
        XCTAssertEqual(HTTPURL(string: "http://host/foo/bar?query#fragment")?.pathSegments, ["foo", "bar"])
        XCTAssertEqual(HTTPURL(string: "http://host#fragment")?.pathSegments, [])
        XCTAssertEqual(HTTPURL(string: "http://host?query")?.pathSegments, [])
    }

    func testLastPathSegment() {
        XCTAssertEqual(HTTPURL(string: "http://foo/bar%20baz")?.lastPathSegment, "bar baz")
        XCTAssertEqual(HTTPURL(string: "http://foo/bar%20baz/")?.lastPathSegment, "bar baz")
        XCTAssertEqual(HTTPURL(string: "http://foo/bar?query#fragment")?.lastPathSegment, "bar")
        XCTAssertNil(HTTPURL(string: "http://#fragment")?.lastPathSegment)
        XCTAssertNil(HTTPURL(string: "http://?query")?.lastPathSegment)
    }

    func testRemovingLastPathSegment() {
        XCTAssertEqual(HTTPURL(string: "http://")?.removingLastPathSegment().string, "http://")
        XCTAssertEqual(HTTPURL(string: "http://foo")?.removingLastPathSegment().string, "http://foo")
        XCTAssertEqual(HTTPURL(string: "http://foo/bar")?.removingLastPathSegment().string, "http://foo/")
        XCTAssertEqual(HTTPURL(string: "http://foo/bar/baz")?.removingLastPathSegment().string, "http://foo/bar/")
    }

    func testPathExtension() {
        XCTAssertEqual(HTTPURL(string: "http://foo/bar.txt")?.pathExtension, "txt")
        XCTAssertNil(HTTPURL(string: "http://foo/bar")?.pathExtension)
        XCTAssertNil(HTTPURL(string: "http://foo/bar/")?.pathExtension)
        XCTAssertNil(HTTPURL(string: "http://foo/.hidden")?.pathExtension)
    }

    func testReplacingPathExtension() {
        XCTAssertEqual(HTTPURL(string: "http://foo/bar")?.replacingPathExtension("xml").string, "http://foo/bar.xml")
        XCTAssertEqual(HTTPURL(string: "http://foo/bar.txt")?.replacingPathExtension("xml").string, "http://foo/bar.xml")
        XCTAssertEqual(HTTPURL(string: "http://foo/bar.txt")?.replacingPathExtension(nil).string, "http://foo/bar")
        XCTAssertEqual(HTTPURL(string: "http://foo/bar/")?.replacingPathExtension("xml").string, "http://foo/bar/")
        XCTAssertEqual(HTTPURL(string: "http://foo/bar/")?.replacingPathExtension(nil).string, "http://foo/bar/")
        XCTAssertEqual(HTTPURL(string: "http://foo")?.replacingPathExtension("xml").string, "http://foo")
    }

    func testQuery() {
        XCTAssertNil(HTTPURL(string: "http://foo/bar")?.query)
        XCTAssertEqual(
            HTTPURL(string: "http://foo/bar?param=quz%20baz")?.query,
            URLQuery(parameters: [.init(name: "param", value: "quz baz")])
        )
    }

    func testRemovingQuery() {
        XCTAssertEqual(HTTPURL(string: "http://foo/bar")?.removingQuery(), HTTPURL(string: "http://foo/bar"))
        XCTAssertEqual(HTTPURL(string: "http://foo/bar?param=quz%20baz")?.removingQuery(), HTTPURL(string: "http://foo/bar"))
    }

    func testFragment() {
        XCTAssertNil(HTTPURL(string: "http://foo/bar")?.fragment)
        XCTAssertEqual(HTTPURL(string: "http://foo/bar#quz%20baz")?.fragment, "quz baz")
    }

    func testRemovingFragment() {
        XCTAssertEqual(HTTPURL(string: "http://foo/bar")?.removingFragment(), HTTPURL(string: "http://foo/bar"))
        XCTAssertEqual(HTTPURL(string: "http://foo/bar#quz%20baz")?.removingFragment(), HTTPURL(string: "http://foo/bar"))
    }

    // MARK: - AbsoluteURL

    func testScheme() {
        XCTAssertEqual(HTTPURL(string: "http://foo/bar")?.scheme, .http)
        XCTAssertEqual(HTTPURL(string: "HTTP://foo/bar")?.scheme, .http)
        XCTAssertEqual(HTTPURL(string: "https://foo/bar")?.scheme, .https)
    }

    func testHost() {
        XCTAssertNil(HTTPURL(string: "http://")?.host)
        XCTAssertNil(HTTPURL(string: "http:///")?.host)
        XCTAssertEqual(HTTPURL(string: "http://domain")?.host, "domain")
        XCTAssertEqual(HTTPURL(string: "http://domain/path")?.host, "domain")
    }

    func testOrigin() {
        XCTAssertEqual(HTTPURL(string: "HTTP://foo/bar")?.origin, "http://foo")
        XCTAssertEqual(HTTPURL(string: "https://foo:443/bar")?.origin, "https://foo:443")
    }

    func testResolveAbsoluteURL() throws {
        let base = try XCTUnwrap(HTTPURL(string: "http://host/foo/bar"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(HTTPURL(string: "http://domain.com")))?.string, "http://domain.com")
        XCTAssertEqual(try base.resolve(XCTUnwrap(UnknownAbsoluteURL(string: "opds://other")))?.string, "opds://other")
        XCTAssertEqual(try base.resolve(XCTUnwrap(FileURL(string: "file:///foo")))?.string, "file:///foo")
    }

    func testResolveRelativeURL() throws {
        var base = try XCTUnwrap(HTTPURL(string: "http://host/foo/bar"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(RelativeURL(string: "quz/baz"))), HTTPURL(string: "http://host/foo/quz/baz"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(RelativeURL(string: "../quz/baz"))), HTTPURL(string: "http://host/quz/baz"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(RelativeURL(string: "/quz/baz"))), HTTPURL(string: "http://host/quz/baz"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(RelativeURL(string: "#fragment"))), HTTPURL(string: "http://host/foo/bar#fragment"))

        // With trailing slash
        base = try XCTUnwrap(HTTPURL(string: "http://host/foo/bar/"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(RelativeURL(string: "quz/baz"))), HTTPURL(string: "http://host/foo/bar/quz/baz"))
        XCTAssertEqual(try base.resolve(XCTUnwrap(RelativeURL(string: "../quz/baz"))), HTTPURL(string: "http://host/foo/quz/baz"))
    }

    func testRelativize() throws {
        var base = try XCTUnwrap(HTTPURL(string: "http://host/foo"))

        XCTAssertNil(try base.relativize(XCTUnwrap(AnyURL(string: "http://host/foo"))))
        XCTAssertEqual(try base.relativize(XCTUnwrap(AnyURL(string: "http://host/foo/quz/baz"))), RelativeURL(string: "quz/baz"))
        XCTAssertEqual(try base.relativize(XCTUnwrap(AnyURL(string: "http://host/foo#fragment"))), RelativeURL(string: "#fragment"))
        XCTAssertNil(try base.relativize(XCTUnwrap(AnyURL(string: "http://host/quz/baz"))))
        XCTAssertNil(try base.relativize(XCTUnwrap(AnyURL(string: "http://host//foo/bar"))))

        // With trailing slash
        base = try XCTUnwrap(HTTPURL(string: "http://host/foo/"))
        XCTAssertEqual(try base.relativize(XCTUnwrap(AnyURL(string: "http://host/foo/quz/baz"))), RelativeURL(string: "quz/baz"))
    }

    func testRelativizeRelativeURL() throws {
        let base = try XCTUnwrap(HTTPURL(string: "http://host/foo"))
        XCTAssertNil(try base.relativize(XCTUnwrap(RelativeURL(string: "host/foo/bar"))))
    }

    func testRelativizeAbsoluteURLWithDifferentScheme() throws {
        let base = try XCTUnwrap(HTTPURL(string: "http://host/foo"))
        XCTAssertNil(try base.relativize(XCTUnwrap(HTTPURL(string: "https://host/foo/bar"))))
        XCTAssertNil(try base.relativize(XCTUnwrap(FileURL(string: "file://host/foo/bar"))))
    }

    func testIsRelative() throws {
        // Only relative with the same origin.
        let url = try XCTUnwrap(HTTPURL(string: "http://host/foo/bar"))
        XCTAssertTrue(try url.isRelative(to: XCTUnwrap(HTTPURL(string: "http://host/foo"))))
        XCTAssertTrue(try url.isRelative(to: XCTUnwrap(HTTPURL(string: "http://host/foo/bar"))))
        XCTAssertTrue(try url.isRelative(to: XCTUnwrap(HTTPURL(string: "http://host/foo/bar/baz"))))
        XCTAssertTrue(try url.isRelative(to: XCTUnwrap(HTTPURL(string: "http://host/bar"))))

        // Different scheme
        XCTAssertFalse(try url.isRelative(to: XCTUnwrap(UnknownAbsoluteURL(string: "other://host/foo"))))
        XCTAssertFalse(try url.isRelative(to: XCTUnwrap(HTTPURL(string: "https://host/foo"))))
        // Different host
        XCTAssertFalse(try url.isRelative(to: XCTUnwrap(HTTPURL(string: "http://foo"))))
        // Relative path
        XCTAssertFalse(try url.isRelative(to: XCTUnwrap(RelativeURL(path: "foo/bar"))))
    }
}
