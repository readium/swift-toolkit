//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import R2Shared
import XCTest

class NonSpecialAbsoluteURLTests: XCTestCase {
    // MARK: - URLProtocol

    func testCreateFromURL() {
        // Only valid for schemes that are not http, https and file.
        XCTAssertNil(NonSpecialAbsoluteURL(url: URL(string: "http://domain.com")!))
        XCTAssertNil(NonSpecialAbsoluteURL(url: URL(string: "https://domain.com")!))
        XCTAssertNil(NonSpecialAbsoluteURL(url: URL(string: "file://domain.com")!))
        XCTAssertEqual(NonSpecialAbsoluteURL(url: URL(string: "opds://callback")!)?.string, "opds://callback")
    }

    func testCreateFromString() {
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "opds://callback")?.string, "opds://callback")

        // Empty
        XCTAssertNil(NonSpecialAbsoluteURL(string: "")?.string)
        // Not absolute
        XCTAssertNil(NonSpecialAbsoluteURL(string: "path"))
        // Only valid for schemes that are not http, https and file.
        XCTAssertNil(NonSpecialAbsoluteURL(string: "http://domain.com"))
        XCTAssertNil(NonSpecialAbsoluteURL(string: "https://domain.com"))
        XCTAssertNil(NonSpecialAbsoluteURL(string: "file://domain.com"))
    }

    func testURL() {
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "opds://foo/bar?query#fragment")?.url, URL(string: "opds://foo/bar?query#fragment")!)
    }

    func testString() {
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "opds://foo/bar?query#fragment")?.string, "opds://foo/bar?query#fragment")
    }

    func testPath() {
        // Path is percent-decoded.
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "opds://host/foo/bar%20baz")?.path, "/foo/bar baz")
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "opds://host/foo/bar%20baz/")?.path, "/foo/bar baz/")
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "opds://host/foo/bar?query#fragment")?.path, "/foo/bar")
        XCTAssertNil(NonSpecialAbsoluteURL(string: "opds://host#fragment")?.path)
        XCTAssertNil(NonSpecialAbsoluteURL(string: "opds://host?query")?.path)
    }

    func testLastPathComponent() {
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "opds://foo/bar%20baz")?.lastPathComponent, "bar baz")
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "opds://foo/bar%20baz/")?.lastPathComponent, "bar baz")
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "opds://foo/bar?query#fragment")?.lastPathComponent, "bar")
        XCTAssertNil(NonSpecialAbsoluteURL(string: "opds://#fragment")?.lastPathComponent)
        XCTAssertNil(NonSpecialAbsoluteURL(string: "opds://?query")?.lastPathComponent)
    }

    func testPathExtension() {
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "opds://foo/bar.txt")?.pathExtension, "txt")
        XCTAssertNil(NonSpecialAbsoluteURL(string: "opds://foo/bar")?.pathExtension)
        XCTAssertNil(NonSpecialAbsoluteURL(string: "opds://foo/bar/")?.pathExtension)
        XCTAssertNil(NonSpecialAbsoluteURL(string: "opds://foo/.hidden")?.pathExtension)
    }

    func testAppendingPath() {
        var base = NonSpecialAbsoluteURL(string: "opds://foo/bar")!
        XCTAssertEqual(base.appendingPath("")?.string, "opds://foo/bar")
        XCTAssertEqual(base.appendingPath("baz/quz")?.string, "opds://foo/bar/baz/quz")
        XCTAssertEqual(base.appendingPath("/baz/quz")?.string, "opds://foo/bar/baz/quz")
        // The path is supposed to be decoded
        XCTAssertEqual(base.appendingPath("baz quz")?.string, "opds://foo/bar/baz%20quz")
        XCTAssertEqual(base.appendingPath("baz%20quz")?.string, "opds://foo/bar/baz%2520quz")
        // Directory
        XCTAssertEqual(base.appendingPath("baz/quz/")?.string, "opds://foo/bar/baz/quz/")
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: true)?.string, "opds://foo/bar/baz/quz/")
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: false)?.string, "opds://foo/bar/baz/quz")

        // With trailing slash.
        base = NonSpecialAbsoluteURL(string: "opds://foo/bar/")!
        XCTAssertEqual(base.appendingPath("baz/quz")?.string, "opds://foo/bar/baz/quz")
    }

    func testQuery() {
        XCTAssertNil(NonSpecialAbsoluteURL(string: "opds://foo/bar")?.query)
        XCTAssertEqual(
            NonSpecialAbsoluteURL(string: "opds://foo/bar?param=quz%20baz")?.query,
            URLQuery(parameters: [.init(name: "param", value: "quz baz")])
        )
    }

    func testRemovingQuery() {
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "opds://foo/bar")?.removingQuery(), NonSpecialAbsoluteURL(string: "opds://foo/bar")!)
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "opds://foo/bar?param=quz%20baz")?.removingQuery(), NonSpecialAbsoluteURL(string: "opds://foo/bar")!)
    }

    func testFragment() {
        XCTAssertNil(NonSpecialAbsoluteURL(string: "opds://foo/bar")?.fragment)
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "opds://foo/bar#quz%20baz")?.fragment, "quz baz")
    }

    func testRemovingFragment() {
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "opds://foo/bar")?.removingFragment(), NonSpecialAbsoluteURL(string: "opds://foo/bar")!)
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "opds://foo/bar#quz%20baz")?.removingFragment(), NonSpecialAbsoluteURL(string: "opds://foo/bar")!)
    }

    // MARK: - AbsoluteURLProtocol

    func testScheme() {
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "opds://foo/bar")?.scheme, URLScheme(rawValue: "opds"))
        XCTAssertEqual(NonSpecialAbsoluteURL(string: "OPDS://foo/bar")?.scheme, URLScheme(rawValue: "opds"))
    }

    func testOrigin() {
        XCTAssertNil(NonSpecialAbsoluteURL(string: "opds://foo/bar")!.origin)
    }

    func testResolveAbsoluteURL() {
        let base = NonSpecialAbsoluteURL(string: "opds://host/foo/bar")!
        XCTAssertNil(base.resolve(NonSpecialAbsoluteURL(string: "opds://other")!))
        XCTAssertNil(base.resolve(HTTPURL(string: "http://domain.com")!))
        XCTAssertNil(base.resolve(FileURL(string: "file:///foo")!))
    }

    func testResolveRelativeURL() {
        var base = NonSpecialAbsoluteURL(string: "opds://host/foo/bar")!
        XCTAssertEqual(base.resolve(RelativeURL(string: "quz/baz")!)!, NonSpecialAbsoluteURL(string: "opds://host/foo/quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "../quz/baz")!)!, NonSpecialAbsoluteURL(string: "opds://host/quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "/quz/baz")!)!, NonSpecialAbsoluteURL(string: "opds://host/quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "#fragment")!)!, NonSpecialAbsoluteURL(string: "opds://host/foo/bar#fragment")!)

        // With trailing slash
        base = NonSpecialAbsoluteURL(string: "opds://host/foo/bar/")!
        XCTAssertEqual(base.resolve(RelativeURL(string: "quz/baz")!)!, NonSpecialAbsoluteURL(string: "opds://host/foo/bar/quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "../quz/baz")!)!, NonSpecialAbsoluteURL(string: "opds://host/foo/quz/baz")!)
    }

    func testRelativize() {
        var base = NonSpecialAbsoluteURL(string: "opds://host/foo")!

        XCTAssertNil(base.relativize(AnyURL(string: "opds://host/foo")!))
        XCTAssertEqual(base.relativize(AnyURL(string: "opds://host/foo/quz/baz")!)!, RelativeURL(string: "quz/baz")!)
        XCTAssertEqual(base.relativize(AnyURL(string: "opds://host/foo#fragment")!)!, RelativeURL(string: "#fragment")!)
        XCTAssertNil(base.relativize(AnyURL(string: "opds://host/quz/baz")!))
        XCTAssertNil(base.relativize(AnyURL(string: "opds://host//foo/bar")!))

        // With trailing slash
        base = NonSpecialAbsoluteURL(string: "opds://host/foo/")!
        XCTAssertEqual(base.relativize(AnyURL(string: "opds://host/foo/quz/baz")!)!, RelativeURL(string: "quz/baz")!)
    }

    func testRelativizeRelativeURL() {
        let base = NonSpecialAbsoluteURL(string: "opds://host/foo")!
        XCTAssertNil(base.relativize(RelativeURL(string: "host/foo/bar")!))
    }

    func testRelativizeAbsoluteURLWithDifferentScheme() {
        let base = NonSpecialAbsoluteURL(string: "opds://host/foo")!
        XCTAssertNil(base.relativize(HTTPURL(string: "http://host/foo/bar")!))
        XCTAssertNil(base.relativize(FileURL(string: "file://host/foo/bar")!))
    }

    func testIsRelative() {
        // Always relative if same scheme.
        let url = NonSpecialAbsoluteURL(string: "opds://host/foo/bar")!
        XCTAssertTrue(url.isRelative(to: NonSpecialAbsoluteURL(string: "opds://host/foo")!))
        XCTAssertTrue(url.isRelative(to: NonSpecialAbsoluteURL(string: "opds://host/foo/bar")!))
        XCTAssertTrue(url.isRelative(to: NonSpecialAbsoluteURL(string: "opds://host/foo/bar/baz")!))
        XCTAssertTrue(url.isRelative(to: NonSpecialAbsoluteURL(string: "opds://host/bar")!))
        XCTAssertTrue(url.isRelative(to: NonSpecialAbsoluteURL(string: "opds://other-host")!))

        // Different scheme
        XCTAssertFalse(url.isRelative(to: NonSpecialAbsoluteURL(string: "other://host/foo")!))
        XCTAssertFalse(url.isRelative(to: HTTPURL(string: "http://foo")!))
        // Relative path
        XCTAssertFalse(url.isRelative(to: RelativeURL(path: "foo/bar")!))
    }
}
