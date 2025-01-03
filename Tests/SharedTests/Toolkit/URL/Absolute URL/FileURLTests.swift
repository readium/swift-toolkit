//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import XCTest

class FileURLTests: XCTestCase {
    func testEquality() {
        XCTAssertEqual(
            FileURL(string: "file:///foo/bar")!,
            FileURL(string: "file:///foo/bar")!
        )
        // Fragments are ignored.
        XCTAssertEqual(
            FileURL(string: "file:///foo/bar")!,
            FileURL(string: "file:///foo/bar#fragment")!
        )
        XCTAssertNotEqual(
            FileURL(string: "file:///foo/bar")!,
            FileURL(string: "file:///foo/baz")!
        )
        XCTAssertNotEqual(
            FileURL(string: "file:///foo/bar")!,
            FileURL(string: "file:///foo/bar/")!
        )
    }

    // MARK: - URLProtocol

    func testCreateFromURL() {
        XCTAssertEqual(FileURL(url: URL(string: "file:///foo/bar")!)?.string, "file:///foo/bar")

        // Only valid for scheme `file`.
        XCTAssertNil(FileURL(url: URL(string: "http://domain.com")!))
        XCTAssertNil(FileURL(url: URL(string: "opds://domain.com")!))
    }

    func testCreateFromString() {
        XCTAssertEqual(FileURL(string: "file:///foo/bar")?.string, "file:///foo/bar")

        // Empty
        XCTAssertNil(FileURL(string: ""))
        XCTAssertNil(FileURL(string: "file://"))
        XCTAssertNil(FileURL(string: "file://#fragment"))
        // Not absolute
        XCTAssertNil(FileURL(string: "path"))
        // Only valid for scheme `file`.
        XCTAssertNil(FileURL(string: "http://domain.com"))
        XCTAssertNil(FileURL(string: "opds://domain.com"))
        // Query and fragment are ignored.
        XCTAssertEqual(FileURL(string: "file:///foo/bar?query#fragment")?.string, "file:///foo/bar")
        // The path is standardized.
        XCTAssertEqual(FileURL(string: "file:///foo/../bar/baz")?.string, "file:///bar/baz")
    }

    func testCreateFromPath() {
        // Empty
        XCTAssertNil(FileURL(path: "/", isDirectory: false))
        // Absolute path
        XCTAssertEqual(FileURL(path: "/foo/bar", isDirectory: false)?.string, "file:///foo/bar")
        // Relative path
        XCTAssertNil(FileURL(path: "foo/bar", isDirectory: false))
        // Containing special characters and ..
        XCTAssertEqual(FileURL(path: "/foo/../bar baz", isDirectory: false)?.string, "file:///bar%20baz")
        XCTAssertEqual(FileURL(path: "/../foo", isDirectory: false)?.string, "file:///foo")

        // Is directory
        XCTAssertEqual(FileURL(path: "/foo/bar/", isDirectory: false)?.string, "file:///foo/bar")
        XCTAssertEqual(FileURL(path: "/foo/bar", isDirectory: true)?.string, "file:///foo/bar/")
        XCTAssertEqual(FileURL(path: "/foo/bar/", isDirectory: true)?.string, "file:///foo/bar/")
    }

    func testURL() {
        XCTAssertEqual(FileURL(string: "file:///foo/bar")?.url, URL(string: "file:///foo/bar")!)
    }

    func testString() {
        XCTAssertEqual(FileURL(string: "file:///foo/bar")?.string, "file:///foo/bar")
    }

    func testPath() {
        // Path is percent-decoded.
        XCTAssertEqual(FileURL(string: "file:///foo/bar%20baz")?.path, "/foo/bar baz")
        XCTAssertEqual(FileURL(string: "file:///foo/bar%20baz/")?.path, "/foo/bar baz/")
    }

    func testAppendingPath() {
        var base = FileURL(string: "file:///foo/bar")!
        XCTAssertEqual(base.appendingPath("", isDirectory: false).string, "file:///foo/bar")
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: false).string, "file:///foo/bar/baz/quz")
        XCTAssertEqual(base.appendingPath("/baz/quz", isDirectory: false).string, "file:///foo/bar/baz/quz")
        // The path is supposed to be decoded
        XCTAssertEqual(base.appendingPath("baz quz", isDirectory: false).string, "file:///foo/bar/baz%20quz")
        XCTAssertEqual(base.appendingPath("baz%20quz", isDirectory: false).string, "file:///foo/bar/baz%2520quz")
        // Directory
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: true).string, "file:///foo/bar/baz/quz/")
        XCTAssertEqual(base.appendingPath("baz/quz/", isDirectory: true).string, "file:///foo/bar/baz/quz/")
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: false).string, "file:///foo/bar/baz/quz")
        XCTAssertEqual(base.appendingPath("baz/quz/", isDirectory: false).string, "file:///foo/bar/baz/quz")

        // With trailing slash.
        base = FileURL(string: "file:///foo/bar/")!
        XCTAssertEqual(base.appendingPath("baz/quz", isDirectory: false).string, "file:///foo/bar/baz/quz")
    }

    func testPathSegments() {
        XCTAssertEqual(FileURL(string: "file:///foo")!.pathSegments, ["foo"])
        XCTAssertEqual(FileURL(string: "file:///foo/bar%20baz")!.pathSegments, ["foo", "bar baz"])
        XCTAssertEqual(FileURL(string: "file:///foo/bar%20baz/")!.pathSegments, ["foo", "bar baz"])
        XCTAssertEqual(FileURL(string: "file:///foo/bar?query#fragment")!.pathSegments, ["foo", "bar"])
    }

    func testLastPathSegment() {
        XCTAssertEqual(FileURL(string: "file:///foo/bar%20baz")!.lastPathSegment, "bar baz")
        XCTAssertEqual(FileURL(string: "file:///foo/bar%20baz/")!.lastPathSegment, "bar baz")
        XCTAssertEqual(FileURL(string: "file:///foo/bar?query#fragment")!.lastPathSegment, "bar")
    }

    func testRemovingLastPathSegment() {
        XCTAssertEqual(FileURL(string: "file:///")!.removingLastPathSegment().string, "file:///")
        XCTAssertEqual(FileURL(string: "file:///foo")!.removingLastPathSegment().string, "file:///")
        XCTAssertEqual(FileURL(string: "file:///foo/bar")!.removingLastPathSegment().string, "file:///foo/")
    }

    func testPathExtension() {
        XCTAssertEqual(FileURL(string: "file:///foo/bar.txt")!.pathExtension, "txt")
        XCTAssertNil(FileURL(string: "file:///foo/bar")!.pathExtension)
        XCTAssertNil(FileURL(string: "file:///foo/bar/")!.pathExtension)
        XCTAssertNil(FileURL(string: "file:///foo/.hidden")!.pathExtension)
    }

    func testReplacingPathExtension() {
        XCTAssertEqual(FileURL(string: "file:///foo/bar")!.replacingPathExtension("xml").string, "file:///foo/bar.xml")
        XCTAssertEqual(FileURL(string: "file:///foo/bar.txt")!.replacingPathExtension("xml").string, "file:///foo/bar.xml")
        XCTAssertEqual(FileURL(string: "file:///foo/bar.txt")!.replacingPathExtension(nil).string, "file:///foo/bar")
        XCTAssertEqual(FileURL(string: "file:///foo/bar/")!.replacingPathExtension("xml").string, "file:///foo/bar/")
        XCTAssertEqual(FileURL(string: "file:///foo/bar/")!.replacingPathExtension(nil).string, "file:///foo/bar/")
    }

    func testQuery() {
        // No query for a file URL.
        XCTAssertNil(FileURL(string: "file:///foo/bar")?.query)
        XCTAssertNil(FileURL(string: "file:///foo/bar?param=quz%20baz")?.query)
    }

    func testRemovingQuery() {
        XCTAssertEqual(FileURL(string: "file:///foo/bar")?.removingQuery(), FileURL(string: "file:///foo/bar")!)
        XCTAssertEqual(FileURL(string: "file:///foo/bar?param=quz%20baz")?.removingQuery(), FileURL(string: "file:///foo/bar")!)
    }

    func testFragment() {
        // No fragment for a file URL.
        XCTAssertNil(FileURL(string: "file:///foo/bar")?.fragment)
        XCTAssertNil(FileURL(string: "file:///foo/bar#quz%20baz")?.fragment)
    }

    func testRemovingFragment() {
        XCTAssertEqual(FileURL(string: "file:///foo/bar")?.removingFragment(), FileURL(string: "file:///foo/bar")!)
        XCTAssertEqual(FileURL(string: "file:///foo/bar#quz%20baz")?.removingFragment(), FileURL(string: "file:///foo/bar")!)
    }

    // MARK: - AbsoluteURL

    func testScheme() {
        XCTAssertEqual(FileURL(string: "file:///foo/bar")!.scheme, .file)
        XCTAssertEqual(FileURL(string: "FILE:///foo/bar")!.scheme, .file)
    }

    func testHost() {
        XCTAssertNil(FileURL(string: "file:///foo/bar")!.host)
    }

    func testOrigin() {
        // Always null for a file URL.
        XCTAssertNil(FileURL(string: "file:///foo/bar")!.origin)
    }

    func testResolveAbsoluteURL() {
        let base = FileURL(string: "file:///foo/bar")!
        XCTAssertEqual(base.resolve(FileURL(string: "file:///foo")!)!.string, "file:///foo")
        XCTAssertEqual(base.resolve(HTTPURL(string: "http://domain.com")!)!.string, "http://domain.com")
        XCTAssertEqual(base.resolve(UnknownAbsoluteURL(string: "opds://other")!)!.string, "opds://other")
    }

    func testResolveRelativeURL() {
        var base = FileURL(string: "file:///foo/bar")!
        XCTAssertEqual(base.resolve(RelativeURL(string: "quz/baz")!)!, FileURL(string: "file:///foo/quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "../quz/baz")!)!, FileURL(string: "file:///quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "/quz/baz")!)!, FileURL(string: "file:///quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "#fragment")!)!, FileURL(string: "file:///foo/bar#fragment")!)

        // With trailing slash
        base = FileURL(string: "file:///foo/bar/")!
        XCTAssertEqual(base.resolve(RelativeURL(string: "quz/baz")!)!, FileURL(string: "file:///foo/bar/quz/baz")!)
        XCTAssertEqual(base.resolve(RelativeURL(string: "../quz/baz")!)!, FileURL(string: "file:///foo/quz/baz")!)
    }

    func testRelativize() {
        var base = FileURL(string: "file:///foo")!

        XCTAssertNil(base.relativize(AnyURL(string: "file:///foo")!))
        XCTAssertEqual(base.relativize(AnyURL(string: "file:///foo/quz/baz")!)!, RelativeURL(string: "quz/baz")!)
        XCTAssertNil(base.relativize(AnyURL(string: "file:///quz/baz")!))

        // With trailing slash
        base = FileURL(string: "file:///foo/")!
        XCTAssertEqual(base.relativize(AnyURL(string: "file:///foo/quz/baz")!)!, RelativeURL(string: "quz/baz")!)
    }

    func testRelativizeRelativeURL() {
        let base = FileURL(string: "file:///foo")!
        XCTAssertNil(base.relativize(RelativeURL(string: "foo/bar")!))
    }

    func testRelativizeAbsoluteURLWithDifferentScheme() {
        let base = FileURL(string: "file:///foo")!
        XCTAssertNil(base.relativize(HTTPURL(string: "https://host/foo/bar")!))
        XCTAssertNil(base.relativize(UnknownAbsoluteURL(string: "opds://host/foo/bar")!))
    }

    func testIsRelative() {
        // Always relative if same scheme.
        let url = FileURL(string: "file:///foo/bar")!
        XCTAssertTrue(url.isRelative(to: FileURL(string: "file:///foo")!))
        XCTAssertTrue(url.isRelative(to: FileURL(string: "file:///foo/bar")!))
        XCTAssertTrue(url.isRelative(to: FileURL(string: "file:///foo/bar/baz")!))
        XCTAssertTrue(url.isRelative(to: FileURL(string: "file:///bar")!))

        // Different scheme
        XCTAssertFalse(url.isRelative(to: UnknownAbsoluteURL(string: "other://host/foo")!))
        XCTAssertFalse(url.isRelative(to: HTTPURL(string: "http://foo")!))
        // Relative path
        XCTAssertFalse(url.isRelative(to: RelativeURL(path: "foo/bar")!))
    }
}
