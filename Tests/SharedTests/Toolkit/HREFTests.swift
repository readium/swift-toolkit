//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
import XCTest

class HREFTests: XCTestCase {
    func testNormalization() {
        assert("", base: "/folder/", equals: "/folder/")
        assert("   ", base: "/folder/", equals: "/folder/")
        assert("/", base: "/folder/", equals: "/")

        assert("foo/bar.txt", base: "", equals: "/foo/bar.txt")
        assert("foo/bar.txt", base: "/", equals: "/foo/bar.txt")
        assert("foo/bar.txt", base: "/file.txt", equals: "/foo/bar.txt")
        assert("foo/bar.txt", base: "/folder", equals: "/foo/bar.txt")
        assert("foo/bar.txt", base: "/folder/", equals: "/folder/foo/bar.txt")
        assert("foo/bar.txt", base: "http://example.com/folder/file.txt", equals: "http://example.com/folder/foo/bar.txt")
        assert("foo/bar.txt", base: "http://example.com/folder", equals: "http://example.com/foo/bar.txt")
        assert("foo/bar.txt", base: "http://example.com/folder/", equals: "http://example.com/folder/foo/bar.txt")

        assert("/foo/bar.txt", base: "", equals: "/foo/bar.txt")
        assert("/foo/bar.txt", base: "/", equals: "/foo/bar.txt")
        assert("/foo/bar.txt", base: "/file.txt", equals: "/foo/bar.txt")
        assert("/foo/bar.txt", base: "/folder", equals: "/foo/bar.txt")
        assert("/foo/bar.txt", base: "/folder/", equals: "/foo/bar.txt")
        assert("/foo/bar.txt", base: "http://example.com/folder/file.txt", equals: "http://example.com/foo/bar.txt")
        assert("/foo/bar.txt", base: "http://example.com/folder", equals: "http://example.com/foo/bar.txt")
        assert("/foo/bar.txt", base: "http://example.com/folder/", equals: "http://example.com/foo/bar.txt")

        assert("../foo/bar.txt", base: "", equals: "/../foo/bar.txt")
        assert("../foo/bar.txt", base: "/", equals: "/../foo/bar.txt")
        assert("../foo/bar.txt", base: "/file.txt", equals: "/../foo/bar.txt")
        assert("../foo/bar.txt", base: "/folder", equals: "/../foo/bar.txt")
        assert("../foo/bar.txt", base: "/folder/", equals: "/foo/bar.txt")
        assert("../foo/bar.txt", base: "http://example.com/folder/file.txt", equals: "http://example.com/foo/bar.txt")
        assert("../foo/bar.txt", base: "http://example.com/folder", equals: "http://example.com/../foo/bar.txt")
        assert("../foo/bar.txt", base: "http://example.com/folder/", equals: "http://example.com/foo/bar.txt")

        assert("foo/../bar.txt", base: "", equals: "/bar.txt")
        assert("foo/../bar.txt", base: "/", equals: "/bar.txt")
        assert("foo/../bar.txt", base: "/file.txt", equals: "/bar.txt")
        assert("foo/../bar.txt", base: "/folder", equals: "/bar.txt")
        assert("foo/../bar.txt", base: "/folder/", equals: "/folder/bar.txt")
        assert("foo/../bar.txt", base: "http://example.com/folder/file.txt", equals: "http://example.com/folder/bar.txt")
        assert("foo/../bar.txt", base: "http://example.com/folder", equals: "http://example.com/bar.txt")
        assert("foo/../bar.txt", base: "http://example.com/folder/", equals: "http://example.com/folder/bar.txt")

        assert("http://absolute.com/foo/bar.txt", base: "/", equals: "http://absolute.com/foo/bar.txt")
        assert("http://absolute.com/foo/bar.txt", base: "https://example.com/", equals: "http://absolute.com/foo/bar.txt")

        // Anchor and query parameters are preserved
        assert("foo/bar.txt#anchor", base: "/", equals: "/foo/bar.txt#anchor")
        assert("foo/bar.txt?query=param#anchor", base: "/", equals: "/foo/bar.txt?query=param#anchor")
        assert("/foo/bar.txt?query=param#anchor", base: "/", equals: "/foo/bar.txt?query=param#anchor")
        assert("http://absolute.com/foo/bar.txt?query=param#anchor", base: "/", equals: "http://absolute.com/foo/bar.txt?query=param#anchor")

        // HREF that is just an anchor
        assert("#anchor", base: "", equals: "/#anchor")
        assert("#anchor", base: "/", equals: "/#anchor")
        assert("#anchor", base: "/file.txt", equals: "/file.txt#anchor")
        assert("#anchor", base: "/folder", equals: "/folder#anchor")
        assert("#anchor", base: "/folder/", equals: "/folder/#anchor")
        assert("#anchor", base: "http://example.com/folder/file.txt", equals: "http://example.com/folder/file.txt#anchor")
        assert("#anchor", base: "http://example.com/folder", equals: "http://example.com/folder#anchor")
        assert("#anchor", base: "http://example.com/folder/", equals: "http://example.com/folder/#anchor")

        // Paths containing special characters
        assert("foo bar/baz qux.txt", base: "/", equals: "/foo bar/baz qux.txt")
        assert("foo bar/baz qux.txt", base: "/base folder", equals: "/foo bar/baz qux.txt")
        assert("foo bar/baz qux.txt", base: "/base folder/", equals: "/base folder/foo bar/baz qux.txt")
        assert("foo bar/baz%qux.txt", base: "/base%folder/", equals: "/base%folder/foo bar/baz%qux.txt")
        assert("foo%20bar/baz%25qux.txt", base: "/base%20folder/", equals: "/base folder/foo bar/baz%qux.txt")
        assert("foo bar/baz qux.txt", base: "http://example.com/base%20folder", equals: "http://example.com/foo%20bar/baz%20qux.txt")
        assert("foo bar/baz qux.txt", base: "http://example.com/base%20folder/", equals: "http://example.com/base%20folder/foo%20bar/baz%20qux.txt")
        assert("foo bar/baz%qux.txt", base: "http://example.com/base%20folder/", equals: "http://example.com/base%20folder/foo%20bar/baz%25qux.txt")
        assert("/foo bar.txt?query=param#anchor", base: "/", equals: "/foo bar.txt?query=param#anchor")
        assert("/foo bar.txt?query=param#anchor", base: "http://example.com/", equals: "http://example.com/foo%20bar.txt?query=param#anchor")
        assert("/foo%20bar.txt?query=param#anchor", base: "http://example.com/", equals: "http://example.com/foo%20bar.txt?query=param#anchor")
        assert("http://absolute.com/foo%20bar.txt?query=param#Hello%20world%20%C2%A3500", base: "/", equals: "http://absolute.com/foo%20bar.txt?query=param#Hello%20world%20%C2%A3500")
    }

    func testQueryParameters() {
        XCTAssertEqual(HREF("http://domain.com/path").queryParameters, [])
        XCTAssertEqual(HREF("http://domain.com/path?query=param#anchor").queryParameters, [
            .init(name: "query", value: "param"),
        ])
        XCTAssertEqual(HREF("http://domain.com/path?query=param&fruit=banana&query=other&empty").queryParameters, [
            .init(name: "query", value: "param"),
            .init(name: "fruit", value: "banana"),
            .init(name: "query", value: "other"),
            .init(name: "empty", value: nil),
        ])
    }

    func testFirstNamed() {
        let params: [HREF.QueryParameter] = [
            .init(name: "query", value: "param"),
            .init(name: "fruit", value: "banana"),
            .init(name: "query", value: "other"),
            .init(name: "empty", value: nil),
        ]

        XCTAssertEqual(params.first(named: "query"), "param")
        XCTAssertEqual(params.first(named: "fruit"), "banana")
        XCTAssertNil(params.first(named: "empty"))
        XCTAssertNil(params.first(named: "not-found"))
    }

    func testAllNamed() {
        let params: [HREF.QueryParameter] = [
            .init(name: "query", value: "param"),
            .init(name: "fruit", value: "banana"),
            .init(name: "query", value: "other"),
            .init(name: "empty", value: nil),
        ]

        XCTAssertEqual(params.all(named: "query"), ["param", "other"])
        XCTAssertEqual(params.all(named: "fruit"), ["banana"])
        XCTAssertEqual(params.all(named: "empty"), [])
        XCTAssertEqual(params.all(named: "not-found"), [])
    }

    private func assert(_ href: String, base: String, equals expected: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(HREF(href, relativeTo: base).string, expected, file: file, line: line)
    }
}
