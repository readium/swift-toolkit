//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import XCTest

class UnknownAbsoluteURLTests: XCTestCase {
    func testEquality() {
        XCTAssertEqual(
            UnknownAbsoluteURL(string: "opds://domain.com")!,
            UnknownAbsoluteURL(string: "opds://domain.com")!
        )
        XCTAssertNotEqual(
            UnknownAbsoluteURL(string: "opds://domain.com")!,
            UnknownAbsoluteURL(string: "opds://domain.com#fragment")!
        )
    }

    // MARK: - URLProtocol

    func testCreateFromURL() {
        XCTAssertEqual(UnknownAbsoluteURL(url: URL(string: "opds://callback")!)?.string, "opds://callback")
    }

    func testCreateFromString() {
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://callback")?.string, "opds://callback")

        // Empty
        XCTAssertNil(UnknownAbsoluteURL(string: "")?.string)
        // Not absolute
        XCTAssertNil(UnknownAbsoluteURL(string: "path"))
    }

    func testURL() {
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar?query#fragment")?.url, URL(string: "opds://foo/bar?query#fragment")!)
    }

    func testString() {
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar?query#fragment")?.string, "opds://foo/bar?query#fragment")
    }

    func testPath() {
        // Path is percent-decoded.
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://host/foo/bar%20baz")?.path, "/foo/bar baz")
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://host/foo/bar%20baz/")?.path, "/foo/bar baz/")
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://host/foo/bar?query#fragment")?.path, "/foo/bar")
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://host#fragment")?.path, "")
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://host?query")?.path, "")
    }

    func testAppendingPath() {
        var base = UnknownAbsoluteURL(string: "opds://foo/bar")!
        XCTAssertEqual(base.appendingPath("", isDirectory: false).string, "opds://foo/bar")
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: false).string, "opds://foo/bar/baz/quz")
        XCTAssertEqual(base.appendingPath("/baz/quz", isDirectory: false).string, "opds://foo/bar/baz/quz")
        // The path is supposed to be decoded
        XCTAssertEqual(base.appendingPath("baz quz", isDirectory: false).string, "opds://foo/bar/baz%20quz")
        XCTAssertEqual(base.appendingPath("baz%20quz", isDirectory: false).string, "opds://foo/bar/baz%2520quz")
        // Directory
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: true).string, "opds://foo/bar/baz/quz/")
        XCTAssertEqual(base.appendingPath("baz/quz/", isDirectory: true).string, "opds://foo/bar/baz/quz/")
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: false).string, "opds://foo/bar/baz/quz")
        XCTAssertEqual(base.appendingPath("baz/quz/", isDirectory: false).string, "opds://foo/bar/baz/quz")

        // With trailing slash.
        base = UnknownAbsoluteURL(string: "opds://foo/bar/")!
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: false).string, "opds://foo/bar/baz/quz")
    }

    func testPathSegments() {
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://host/foo")?.pathSegments, ["foo"])
        // Segments are percent-decoded.
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://host/foo/bar%20baz")?.pathSegments, ["foo", "bar baz"])
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://host/foo/bar%20baz/")?.pathSegments, ["foo", "bar baz"])
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://host/foo/bar?query#fragment")?.pathSegments, ["foo", "bar"])
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://host#fragment")?.pathSegments, [])
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://host?query")?.pathSegments, [])
    }

    func testLastPathSegment() {
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar%20baz")?.lastPathSegment, "bar baz")
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar%20baz/")?.lastPathSegment, "bar baz")
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar?query#fragment")?.lastPathSegment, "bar")
        XCTAssertNil(UnknownAbsoluteURL(string: "opds://#fragment")?.lastPathSegment)
        XCTAssertNil(UnknownAbsoluteURL(string: "opds://?query")?.lastPathSegment)
    }

    func testRemovingLastPathSegment() {
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://")!.removingLastPathSegment().string, "opds://")
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo")!.removingLastPathSegment().string, "opds://foo")
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar")!.removingLastPathSegment().string, "opds://foo/")
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar/baz")!.removingLastPathSegment().string, "opds://foo/bar/")
    }

    func testPathExtension() {
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar.txt")?.pathExtension, "txt")
        XCTAssertNil(UnknownAbsoluteURL(string: "opds://foo/bar")?.pathExtension)
        XCTAssertNil(UnknownAbsoluteURL(string: "opds://foo/bar/")?.pathExtension)
        XCTAssertNil(UnknownAbsoluteURL(string: "opds://foo/.hidden")?.pathExtension)
    }

    func testReplacingPathExtension() {
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar")!.replacingPathExtension("xml").string, "opds://foo/bar.xml")
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar.txt")!.replacingPathExtension("xml").string, "opds://foo/bar.xml")
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar.txt")!.replacingPathExtension(nil).string, "opds://foo/bar")
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar/")!.replacingPathExtension("xml").string, "opds://foo/bar/")
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar/")!.replacingPathExtension(nil).string, "opds://foo/bar/")
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo")!.replacingPathExtension("xml").string, "opds://foo")
    }

    func testQuery() {
        XCTAssertNil(UnknownAbsoluteURL(string: "opds://foo/bar")?.query)
        XCTAssertEqual(
            UnknownAbsoluteURL(string: "opds://foo/bar?param=quz%20baz")?.query,
            URLQuery(parameters: [.init(name: "param", value: "quz baz")])
        )
    }

    func testRemovingQuery() {
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar")?.removingQuery(), UnknownAbsoluteURL(string: "opds://foo/bar")!)
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar?param=quz%20baz")?.removingQuery(), UnknownAbsoluteURL(string: "opds://foo/bar")!)
    }

    func testFragment() {
        XCTAssertNil(UnknownAbsoluteURL(string: "opds://foo/bar")?.fragment)
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar#quz%20baz")?.fragment, "quz baz")
    }

    func testRemovingFragment() {
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar")?.removingFragment(), UnknownAbsoluteURL(string: "opds://foo/bar")!)
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar#quz%20baz")?.removingFragment(), UnknownAbsoluteURL(string: "opds://foo/bar")!)
    }

    // MARK: - AbsoluteURL

    func testScheme() {
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://foo/bar")?.scheme, URLScheme(rawValue: "opds"))
        XCTAssertEqual(UnknownAbsoluteURL(string: "OPDS://foo/bar")?.scheme, URLScheme(rawValue: "opds"))
    }

    func testHost() {
        XCTAssertNil(UnknownAbsoluteURL(string: "opds://")!.host)
        XCTAssertNil(UnknownAbsoluteURL(string: "opds:///")!.host)
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://domain")!.host, "domain")
        XCTAssertEqual(UnknownAbsoluteURL(string: "opds://domain/path")!.host, "domain")
    }

    func testOrigin() {
        XCTAssertNil(UnknownAbsoluteURL(string: "opds://foo/bar")!.origin)
    }

    func testResolveAbsoluteURL() {
        let base = UnknownAbsoluteURL(string: "opds://host/foo/bar")!
        XCTAssertEqual(base.resolve(UnknownAbsoluteURL(string: "opds://other")!)!.string, "opds://other")
        XCTAssertEqual(base.resolve(HTTPURL(string: "http://domain.com")!)!.string, "http://domain.com")
        XCTAssertEqual(base.resolve(FileURL(string: "file:///foo")!)!.string, "file:///foo")
    }

    func testResolveRelativeURL() {
        var base = UnknownAbsoluteURL(string: "opds://host/foo/bar")!
        XCTAssertEqual(base.resolve(RelativeURL(string: "quz/baz")!)!, UnknownAbsoluteURL(string: "opds://host/foo/quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "../quz/baz")!)!, UnknownAbsoluteURL(string: "opds://host/quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "/quz/baz")!)!, UnknownAbsoluteURL(string: "opds://host/quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "#fragment")!)!, UnknownAbsoluteURL(string: "opds://host/foo/bar#fragment")!)

        // With trailing slash
        base = UnknownAbsoluteURL(string: "opds://host/foo/bar/")!
        XCTAssertEqual(base.resolve(RelativeURL(string: "quz/baz")!)!, UnknownAbsoluteURL(string: "opds://host/foo/bar/quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "../quz/baz")!)!, UnknownAbsoluteURL(string: "opds://host/foo/quz/baz")!)
    }

    func testRelativize() {
        var base = UnknownAbsoluteURL(string: "opds://host/foo")!

        XCTAssertNil(base.relativize(AnyURL(string: "opds://host/foo")!))
        XCTAssertEqual(base.relativize(AnyURL(string: "opds://host/foo/quz/baz")!)!, RelativeURL(string: "quz/baz")!)
        XCTAssertEqual(base.relativize(AnyURL(string: "opds://host/foo#fragment")!)!, RelativeURL(string: "#fragment")!)
        XCTAssertNil(base.relativize(AnyURL(string: "opds://host/quz/baz")!))
        XCTAssertNil(base.relativize(AnyURL(string: "opds://host//foo/bar")!))

        // With trailing slash
        base = UnknownAbsoluteURL(string: "opds://host/foo/")!
        XCTAssertEqual(base.relativize(AnyURL(string: "opds://host/foo/quz/baz")!)!, RelativeURL(string: "quz/baz")!)
    }

    func testRelativizeRelativeURL() {
        let base = UnknownAbsoluteURL(string: "opds://host/foo")!
        XCTAssertNil(base.relativize(RelativeURL(string: "host/foo/bar")!))
    }

    func testRelativizeAbsoluteURLWithDifferentScheme() {
        let base = UnknownAbsoluteURL(string: "opds://host/foo")!
        XCTAssertNil(base.relativize(HTTPURL(string: "http://host/foo/bar")!))
        XCTAssertNil(base.relativize(FileURL(string: "file://host/foo/bar")!))
    }

    func testIsRelative() {
        // Always relative if same scheme.
        let url = UnknownAbsoluteURL(string: "opds://host/foo/bar")!
        XCTAssertTrue(url.isRelative(to: UnknownAbsoluteURL(string: "opds://host/foo")!))
        XCTAssertTrue(url.isRelative(to: UnknownAbsoluteURL(string: "opds://host/foo/bar")!))
        XCTAssertTrue(url.isRelative(to: UnknownAbsoluteURL(string: "opds://host/foo/bar/baz")!))
        XCTAssertTrue(url.isRelative(to: UnknownAbsoluteURL(string: "opds://host/bar")!))
        XCTAssertTrue(url.isRelative(to: UnknownAbsoluteURL(string: "opds://other-host")!))

        // Different scheme
        XCTAssertFalse(url.isRelative(to: UnknownAbsoluteURL(string: "other://host/foo")!))
        XCTAssertFalse(url.isRelative(to: HTTPURL(string: "http://foo")!))
        // Relative path
        XCTAssertFalse(url.isRelative(to: RelativeURL(path: "foo/bar")!))
    }
}
