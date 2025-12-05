//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

import Foundation
@testable import ReadiumShared
import XCTest

class RelativeURLTests: XCTestCase {
    func testEquality() {
        XCTAssertEqual(
            RelativeURL(string: "dir/file")!,
            RelativeURL(string: "dir/file")!
        )
        XCTAssertNotEqual(
            RelativeURL(string: "dir/file/")!,
            RelativeURL(string: "dir/file")!
        )
        XCTAssertNotEqual(
            RelativeURL(string: "dir")!,
            RelativeURL(string: "dir/file")!
        )
    }

    // MARK: - URLProtocol

    func testCreateFromURL() {
        XCTAssertNil(RelativeURL(url: URL(string: "https://domain.com")!))
        XCTAssertNil(RelativeURL(url: URL(fileURLWithPath: "/dir/file")))
        XCTAssertEqual(RelativeURL(url: URL(string: "/dir/file")!)?.string, "/dir/file")
    }

    func testCreateFromPath() {
        // Empty
        XCTAssertNil(RelativeURL(path: "")?.string, "")
        // Whitespace
        XCTAssertEqual(RelativeURL(path: "  ")?.string, "%20%20")
        // Relative path
        XCTAssertEqual(RelativeURL(path: "foo/bar")?.string, "foo/bar")
        // Absolute to root
        XCTAssertEqual(RelativeURL(path: "/foo/bar")?.string, "/foo/bar")
        // Containing special characters valid in a path
        XCTAssertEqual(RelativeURL(path: "$&+,/=@")?.string, "$&+,/=@")
        // Containing special characters and ..
        XCTAssertEqual(RelativeURL(path: "foo/../bar baz")?.string, "foo/../bar%20baz")
        XCTAssertEqual(RelativeURL(path: "../foo")?.string, "../foo")
    }

    func testCreateFromString() {
        // Empty
        XCTAssertNil(RelativeURL(string: "")?.string)
        // Whitespace
        XCTAssertEqual(RelativeURL(string: "%20%20")?.string, "%20%20")
        // Percent-encoded special characters
        XCTAssertEqual(RelativeURL(string: "foo/../bar%20baz?query#fragment")?.string, "foo/../bar%20baz?query#fragment")
        // Invalid characters
        XCTAssertNil(RelativeURL(string: "foo/../bar baz"))
        // Absolute URL
        XCTAssertNil(RelativeURL(string: "https://domain.com"))
        XCTAssertNil(RelativeURL(string: "file:///dir/file"))
        // Fragment only
        XCTAssertEqual(RelativeURL(string: "#")?.string, "#")
        XCTAssertEqual(RelativeURL(string: "#fragment")?.string, "#fragment")
        // Query only
        XCTAssertEqual(RelativeURL(string: "?query=foo%bar")?.string, "?query=foo%bar")
    }

    func testURL() {
        XCTAssertEqual(RelativeURL(string: "foo/bar?query#fragment")?.url, URL(string: "foo/bar?query#fragment")!)
    }

    func testString() {
        XCTAssertEqual(RelativeURL(string: "foo/bar?query#fragment")?.string, "foo/bar?query#fragment")
    }

    func testPath() {
        // Path is percent-decoded.
        XCTAssertEqual(RelativeURL(string: "foo/bar%20baz")?.path, "foo/bar baz")
        XCTAssertEqual(RelativeURL(string: "foo/bar%20baz/")?.path, "foo/bar baz/")
        XCTAssertEqual(RelativeURL(string: "/foo/bar%20baz")?.path, "/foo/bar baz")
        XCTAssertEqual(RelativeURL(string: "foo/bar?query#fragment")?.path, "foo/bar")
        XCTAssertEqual(RelativeURL(string: "#fragment")?.path, "")
        XCTAssertEqual(RelativeURL(string: "?query")?.path, "")
    }

    func testAppendingPath() {
        var base = RelativeURL(string: "foo/bar")!
        XCTAssertEqual(base.appendingPath("", isDirectory: false).string, "foo/bar")
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: false).string, "foo/bar/baz/quz")
        XCTAssertEqual(base.appendingPath("/baz/quz", isDirectory: false).string, "foo/bar/baz/quz")
        // The path is supposed to be decoded
        XCTAssertEqual(base.appendingPath("baz quz", isDirectory: false).string, "foo/bar/baz%20quz")
        XCTAssertEqual(base.appendingPath("baz%20quz", isDirectory: false).string, "foo/bar/baz%2520quz")
        // Directory
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: true).string, "foo/bar/baz/quz/")
        XCTAssertEqual(base.appendingPath("baz/quz/", isDirectory: true).string, "foo/bar/baz/quz/")
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: false).string, "foo/bar/baz/quz")
        XCTAssertEqual(base.appendingPath("baz/quz/", isDirectory: false).string, "foo/bar/baz/quz")

        // With trailing slash.
        base = RelativeURL(string: "foo/bar/")!
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: false).string, "foo/bar/baz/quz")
    }

    func testPathSegments() {
        XCTAssertEqual(RelativeURL(string: "foo")?.pathSegments, ["foo"])
        // Segments are percent-decoded.
        XCTAssertEqual(RelativeURL(string: "foo/bar%20baz")?.pathSegments, ["foo", "bar baz"])
        XCTAssertEqual(RelativeURL(string: "foo/bar%20baz/")?.pathSegments, ["foo", "bar baz"])
        XCTAssertEqual(RelativeURL(string: "/foo/bar%20baz")?.pathSegments, ["foo", "bar baz"])
        XCTAssertEqual(RelativeURL(string: "foo/bar?query#fragment")?.pathSegments, ["foo", "bar"])
        XCTAssertEqual(RelativeURL(string: "#fragment")?.pathSegments, [])
        XCTAssertEqual(RelativeURL(string: "?query")?.pathSegments, [])
    }

    func testLastPathSegment() {
        XCTAssertEqual(RelativeURL(string: "foo/bar%20baz")?.lastPathSegment, "bar baz")
        XCTAssertEqual(RelativeURL(string: "foo/bar%20baz/")?.lastPathSegment, "bar baz")
        XCTAssertEqual(RelativeURL(string: "foo/bar?query#fragment")?.lastPathSegment, "bar")
        XCTAssertNil(RelativeURL(string: "#fragment")?.lastPathSegment)
        XCTAssertNil(RelativeURL(string: "?query")?.lastPathSegment)
    }

    func testRemovingLastPathSegment() {
        XCTAssertEqual(RelativeURL(string: "foo")!.removingLastPathSegment().string, "./")
        XCTAssertEqual(RelativeURL(string: "foo/bar")!.removingLastPathSegment().string, "foo/")
        XCTAssertEqual(RelativeURL(string: "foo/bar/")!.removingLastPathSegment().string, "foo/")
        XCTAssertEqual(RelativeURL(string: "/foo")!.removingLastPathSegment().string, "/")
        XCTAssertEqual(RelativeURL(string: "/foo/bar")!.removingLastPathSegment().string, "/foo/")
        XCTAssertEqual(RelativeURL(string: "/foo/bar/")!.removingLastPathSegment().string, "/foo/")
    }

    func testPathExtension() {
        XCTAssertEqual(RelativeURL(string: "foo/bar.txt")?.pathExtension, "txt")
        XCTAssertNil(RelativeURL(string: "foo/bar")?.pathExtension)
        XCTAssertNil(RelativeURL(string: "foo/bar/")?.pathExtension)
        XCTAssertNil(RelativeURL(string: "foo/.hidden")?.pathExtension)
    }

    func testReplacingPathExtension() {
        XCTAssertEqual(RelativeURL(string: "/foo/bar")!.replacingPathExtension("xml").string, "/foo/bar.xml")
        XCTAssertEqual(RelativeURL(string: "/foo/bar.txt")!.replacingPathExtension("xml").string, "/foo/bar.xml")
        XCTAssertEqual(RelativeURL(string: "/foo/bar.txt")!.replacingPathExtension(nil).string, "/foo/bar")
        XCTAssertEqual(RelativeURL(string: "/foo/bar/")!.replacingPathExtension("xml").string, "/foo/bar/")
        XCTAssertEqual(RelativeURL(string: "/foo/bar/")!.replacingPathExtension(nil).string, "/foo/bar/")
    }

    func testQuery() {
        XCTAssertNil(RelativeURL(string: "foo/bar")?.query)
        XCTAssertEqual(
            RelativeURL(string: "foo/bar?param=quz%20baz")?.query,
            URLQuery(parameters: [.init(name: "param", value: "quz baz")])
        )
    }

    func testRemovingQuery() {
        XCTAssertEqual(RelativeURL(string: "foo/bar")?.removingQuery(), RelativeURL(string: "foo/bar")!)
        XCTAssertEqual(RelativeURL(string: "foo/bar?param=quz%20baz")?.removingQuery(), RelativeURL(string: "foo/bar")!)
    }

    func testFragment() {
        XCTAssertNil(RelativeURL(string: "foo/bar")?.fragment)
        XCTAssertEqual(RelativeURL(string: "foo/bar#quz%20baz")?.fragment, "quz baz")
    }

    func testRemovingFragment() {
        XCTAssertEqual(RelativeURL(string: "foo/bar")?.removingFragment(), RelativeURL(string: "foo/bar")!)
        XCTAssertEqual(RelativeURL(string: "foo/bar#quz%20baz")?.removingFragment(), RelativeURL(string: "foo/bar")!)
    }

    // MARK: - RelativeURL

    func testResolveURLConvertible() {
        let base = RelativeURL(string: "foo/bar")!
        XCTAssertEqual(base.resolve(AnyURL(string: "quz")!)?.string, "foo/quz")
        XCTAssertEqual(base.resolve(HTTPURL(string: "http://domain.com")!)!.string, "http://domain.com")
        XCTAssertEqual(base.resolve(FileURL(string: "file:///foo")!)!.string, "file:///foo")
    }

    func testResolveRelativeURL() {
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

    func testRelativize() {
        var base = RelativeURL(string: "foo")!

        XCTAssertEqual(base.relativize(AnyURL(string: "foo/quz/baz")!)!, RelativeURL(string: "quz/baz")!)
        XCTAssertEqual(base.relativize(AnyURL(string: "foo#fragment")!)!, RelativeURL(string: "#fragment")!)
        XCTAssertNil(base.relativize(AnyURL(string: "quz/baz")!))
        XCTAssertNil(base.relativize(AnyURL(string: "/foo/bar")!))

        // With trailing slash
        base = RelativeURL(string: "foo/")!
        XCTAssertEqual(base.relativize(AnyURL(string: "foo/quz/baz")!)!, RelativeURL(string: "quz/baz")!)

        // With starting slash
        base = RelativeURL(string: "/foo")!
        XCTAssertEqual(base.relativize(AnyURL(string: "/foo/quz/baz")!)!, RelativeURL(string: "quz/baz")!)
        XCTAssertNil(base.relativize(AnyURL(string: "foo/quz")!))
        XCTAssertNil(base.relativize(AnyURL(string: "/quz/baz")!))
    }

    func testRelativizeAbsoluteURL() {
        let base = RelativeURL(string: "foo")!
        XCTAssertNil(base.relativize(HTTPURL(string: "http://example.com/foo/bar")!))
        XCTAssertNil(base.relativize(FileURL(string: "file:///foo")!))
    }
}
