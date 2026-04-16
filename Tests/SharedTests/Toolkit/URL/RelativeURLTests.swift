//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

enum RelativeURLTests {
    struct Equality {
        @Test("equal URLs compare as equal")
        func equality() throws {
            #expect(RelativeURL(string: "dir/file") == RelativeURL(string: "dir/file"))
            #expect(try #require(RelativeURL(string: "dir/file/")) != #require(RelativeURL(string: "dir/file")))
            #expect(try #require(RelativeURL(string: "dir")) != #require(RelativeURL(string: "dir/file")))
        }
    }

    struct URLProtocolImplementation {
        @Test("creates from Foundation URL")
        func createFromURL() throws {
            #expect(try RelativeURL(url: #require(URL(string: "https://domain.com"))) == nil)
            #expect(RelativeURL(url: URL(fileURLWithPath: "/dir/file")) == nil)
            #expect(try RelativeURL(url: #require(URL(string: "/dir/file")))?.string == "/dir/file")
        }

        @Test("creates from decoded path string")
        func createFromPath() {
            // Empty
            #expect(RelativeURL(path: "")?.string == nil)
            // Whitespace
            #expect(RelativeURL(path: "  ")?.string == "%20%20")
            // Relative path
            #expect(RelativeURL(path: "foo/bar")?.string == "foo/bar")
            // Absolute to root
            #expect(RelativeURL(path: "/foo/bar")?.string == "/foo/bar")
            // Containing special characters valid in a path
            #expect(RelativeURL(path: "$&+,/=@")?.string == "$&+,/=@")
            // Containing special characters and ..
            #expect(RelativeURL(path: "foo/../bar baz")?.string == "foo/../bar%20baz")
            #expect(RelativeURL(path: "../foo")?.string == "../foo")
        }

        @Test("creates from percent-encoded string")
        func createFromString() {
            // Empty
            #expect(RelativeURL(string: "")?.string == nil)
            // Whitespace
            #expect(RelativeURL(string: "%20%20")?.string == "%20%20")
            // Percent-encoded special characters
            #expect(RelativeURL(string: "foo/../bar%20baz?query#fragment")?.string == "foo/../bar%20baz?query#fragment")
            // Invalid characters
            #expect(RelativeURL(string: "foo/../bar baz") == nil)
            // Absolute URL
            #expect(RelativeURL(string: "https://domain.com") == nil)
            #expect(RelativeURL(string: "file:///dir/file") == nil)
            // Fragment only
            #expect(RelativeURL(string: "#")?.string == "#")
            #expect(RelativeURL(string: "#fragment")?.string == "#fragment")
            // Query only
            #expect(RelativeURL(string: "?query=foo%bar")?.string == "?query=foo%bar")
        }

        @Test("url property returns Foundation URL")
        func url() {
            #expect(RelativeURL(string: "foo/bar?query#fragment")?.url == URL(string: "foo/bar?query#fragment"))
        }

        @Test("string property returns percent-encoded string")
        func string() {
            #expect(RelativeURL(string: "foo/bar?query#fragment")?.string == "foo/bar?query#fragment")
        }

        @Test("path is percent-decoded")
        func path() {
            #expect(RelativeURL(string: "foo/bar%20baz")?.path == "foo/bar baz")
            #expect(RelativeURL(string: "foo/bar%20baz/")?.path == "foo/bar baz/")
            #expect(RelativeURL(string: "/foo/bar%20baz")?.path == "/foo/bar baz")
            #expect(RelativeURL(string: "foo/bar?query#fragment")?.path == "foo/bar")
            #expect(RelativeURL(string: "#fragment")?.path == "")
            #expect(RelativeURL(string: "?query")?.path == "")
        }

        @Test("appendingPath appends a decoded path segment")
        func appendingPath() throws {
            var base = try #require(RelativeURL(string: "foo/bar"))
            #expect(base.appendingPath("", isDirectory: false).string == "foo/bar")
            #expect(base.appendingPath("baz/quz", isDirectory: false).string == "foo/bar/baz/quz")
            #expect(base.appendingPath("/baz/quz", isDirectory: false).string == "foo/bar/baz/quz")
            // The path is supposed to be decoded
            #expect(base.appendingPath("baz quz", isDirectory: false).string == "foo/bar/baz%20quz")
            #expect(base.appendingPath("baz%20quz", isDirectory: false).string == "foo/bar/baz%2520quz")
            // Directory
            #expect(base.appendingPath("baz/quz", isDirectory: true).string == "foo/bar/baz/quz/")
            #expect(base.appendingPath("baz/quz/", isDirectory: true).string == "foo/bar/baz/quz/")
            #expect(base.appendingPath("baz/quz", isDirectory: false).string == "foo/bar/baz/quz")
            #expect(base.appendingPath("baz/quz/", isDirectory: false).string == "foo/bar/baz/quz")

            // With trailing slash.
            base = try #require(RelativeURL(string: "foo/bar/"))
            #expect(base.appendingPath("baz/quz", isDirectory: false).string == "foo/bar/baz/quz")
        }

        @Test("pathSegments returns percent-decoded segments")
        func pathSegments() {
            #expect(RelativeURL(string: "foo")?.pathSegments == ["foo"])
            // Segments are percent-decoded.
            #expect(RelativeURL(string: "foo/bar%20baz")?.pathSegments == ["foo", "bar baz"])
            #expect(RelativeURL(string: "foo/bar%20baz/")?.pathSegments == ["foo", "bar baz"])
            #expect(RelativeURL(string: "/foo/bar%20baz")?.pathSegments == ["foo", "bar baz"])
            #expect(RelativeURL(string: "foo/bar?query#fragment")?.pathSegments == ["foo", "bar"])
            #expect(RelativeURL(string: "#fragment")?.pathSegments == [])
            #expect(RelativeURL(string: "?query")?.pathSegments == [])
        }

        @Test("lastPathSegment returns the last decoded segment")
        func lastPathSegment() {
            #expect(RelativeURL(string: "foo/bar%20baz")?.lastPathSegment == "bar baz")
            #expect(RelativeURL(string: "foo/bar%20baz/")?.lastPathSegment == "bar baz")
            #expect(RelativeURL(string: "foo/bar?query#fragment")?.lastPathSegment == "bar")
            #expect(RelativeURL(string: "#fragment")?.lastPathSegment == nil)
            #expect(RelativeURL(string: "?query")?.lastPathSegment == nil)
        }

        @Test("removingLastPathSegment removes the last path segment")
        func removingLastPathSegment() {
            #expect(RelativeURL(string: "foo")?.removingLastPathSegment().string == "./")
            #expect(RelativeURL(string: "foo/bar")?.removingLastPathSegment().string == "foo/")
            #expect(RelativeURL(string: "foo/bar/")?.removingLastPathSegment().string == "foo/")
            #expect(RelativeURL(string: "/foo")?.removingLastPathSegment().string == "/")
            #expect(RelativeURL(string: "/foo/bar")?.removingLastPathSegment().string == "/foo/")
            #expect(RelativeURL(string: "/foo/bar/")?.removingLastPathSegment().string == "/foo/")
        }

        @Test("pathExtension returns the file extension")
        func pathExtension() {
            #expect(RelativeURL(string: "foo/bar.txt")?.pathExtension == "txt")
            #expect(RelativeURL(string: "foo/bar")?.pathExtension == nil)
            #expect(RelativeURL(string: "foo/bar/")?.pathExtension == nil)
            #expect(RelativeURL(string: "foo/.hidden")?.pathExtension == nil)
        }

        @Test("replacingPathExtension replaces or removes the file extension")
        func replacingPathExtension() {
            #expect(RelativeURL(string: "/foo/bar")?.replacingPathExtension("xml").string == "/foo/bar.xml")
            #expect(RelativeURL(string: "/foo/bar.txt")?.replacingPathExtension("xml").string == "/foo/bar.xml")
            #expect(RelativeURL(string: "/foo/bar.txt")?.replacingPathExtension(nil).string == "/foo/bar")
            #expect(RelativeURL(string: "/foo/bar/")?.replacingPathExtension("xml").string == "/foo/bar/")
            #expect(RelativeURL(string: "/foo/bar/")?.replacingPathExtension(nil).string == "/foo/bar/")
        }

        @Test("query returns parsed query parameters")
        func query() {
            #expect(RelativeURL(string: "foo/bar")?.query == nil)
            #expect(
                RelativeURL(string: "foo/bar?param=quz%20baz")?.query
                    == URLQuery(parameters: [.init(name: "param", value: "quz baz")])
            )
        }

        @Test("removingQuery removes the query component")
        func removingQuery() {
            #expect(RelativeURL(string: "foo/bar")?.removingQuery() == RelativeURL(string: "foo/bar"))
            #expect(RelativeURL(string: "foo/bar?param=quz%20baz")?.removingQuery() == RelativeURL(string: "foo/bar"))
        }

        @Test("fragment is percent-decoded")
        func fragment() {
            #expect(RelativeURL(string: "foo/bar")?.fragment == nil)
            #expect(RelativeURL(string: "foo/bar#quz%20baz")?.fragment == "quz baz")
        }

        @Test("removingFragment removes the fragment component")
        func removingFragment() {
            #expect(RelativeURL(string: "foo/bar")?.removingFragment() == RelativeURL(string: "foo/bar"))
            #expect(RelativeURL(string: "foo/bar#quz%20baz")?.removingFragment() == RelativeURL(string: "foo/bar"))
        }

        @Test("replacingFragment sets or removes the fragment")
        func replacingFragment() {
            // Sets fragment on URL without one.
            #expect(RelativeURL(string: "foo/bar")?.replacingFragment("baz").string == "foo/bar#baz")
            // Replaces existing fragment.
            #expect(RelativeURL(string: "foo/bar#old")?.replacingFragment("new").string == "foo/bar#new")
            // Removing via nil matches removingFragment().
            #expect(RelativeURL(string: "foo/bar#quz%20baz")?.replacingFragment(nil) == RelativeURL(string: "foo/bar"))
            // Fragment is percent-encoded.
            #expect(RelativeURL(string: "foo/bar")?.replacingFragment("quz baz").string == "foo/bar#quz%20baz")
        }
    }

    struct RelativeURLImplementation {
        @Test("resolves against any URLConvertible")
        func resolveURLConvertible() throws {
            let base = try #require(RelativeURL(string: "foo/bar"))
            #expect(try base.resolve(#require(AnyURL(string: "quz")))?.string == "foo/quz")
            #expect(try base.resolve(#require(HTTPURL(string: "http://domain.com")))?.string == "http://domain.com")
            #expect(try base.resolve(#require(FileURL(string: "file:///foo")))?.string == "file:///foo")
        }

        @Test("resolves relative URL against another relative URL")
        func resolveRelativeURL() throws {
            var base = try #require(RelativeURL(string: "foo/bar"))
            #expect(try base.resolve(#require(RelativeURL(string: "quz/baz"))) == RelativeURL(string: "foo/quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "../quz/baz"))) == RelativeURL(string: "quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "/quz/baz"))) == RelativeURL(string: "/quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "#fragment"))) == RelativeURL(string: "foo/bar#fragment"))

            // With trailing slash
            base = try #require(RelativeURL(string: "foo/bar/"))
            #expect(try base.resolve(#require(RelativeURL(string: "quz/baz"))) == RelativeURL(string: "foo/bar/quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "../quz/baz"))) == RelativeURL(string: "foo/quz/baz"))

            // With starting slash
            base = try #require(RelativeURL(string: "/foo/bar"))
            #expect(try base.resolve(#require(RelativeURL(string: "quz/baz"))) == RelativeURL(string: "/foo/quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "/quz/baz"))) == RelativeURL(string: "/quz/baz"))
        }

        @Test("relativizes a URL against this base")
        func relativize() throws {
            var base = try #require(RelativeURL(string: "foo"))
            #expect(try base.relativize(#require(AnyURL(string: "foo/quz/baz"))) == RelativeURL(string: "quz/baz"))
            #expect(try base.relativize(#require(AnyURL(string: "foo#fragment"))) == RelativeURL(string: "#fragment"))
            #expect(try base.relativize(#require(AnyURL(string: "quz/baz"))) == nil)
            #expect(try base.relativize(#require(AnyURL(string: "/foo/bar"))) == nil)

            // With trailing slash
            base = try #require(RelativeURL(string: "foo/"))
            #expect(try base.relativize(#require(AnyURL(string: "foo/quz/baz"))) == RelativeURL(string: "quz/baz"))

            // With starting slash
            base = try #require(RelativeURL(string: "/foo"))
            #expect(try base.relativize(#require(AnyURL(string: "/foo/quz/baz"))) == RelativeURL(string: "quz/baz"))
            #expect(try base.relativize(#require(AnyURL(string: "foo/quz"))) == nil)
            #expect(try base.relativize(#require(AnyURL(string: "/quz/baz"))) == nil)
        }

        @Test("absolute URL returns nil when relativized against a relative base")
        func relativizeAbsoluteURL() throws {
            let base = try #require(RelativeURL(string: "foo"))
            #expect(try base.relativize(#require(HTTPURL(string: "http://example.com/foo/bar"))) == nil)
            #expect(try base.relativize(#require(FileURL(string: "file:///foo"))) == nil)
        }
    }
}
