//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

enum FileURLTests {
    struct Equality {
        @Test("equal URLs compare as equal, fragments are ignored")
        func equality() throws {
            #expect(FileURL(string: "file:///foo/bar") == FileURL(string: "file:///foo/bar"))
            // Fragments are ignored.
            #expect(FileURL(string: "file:///foo/bar") == FileURL(string: "file:///foo/bar#fragment"))
            #expect(
                try #require(FileURL(string: "file:///foo/bar"))
                    != #require(FileURL(string: "file:///foo/baz"))
            )
            #expect(
                try #require(FileURL(string: "file:///foo/bar"))
                    != #require(FileURL(string: "file:///foo/bar/"))
            )
        }
    }

    struct URLProtocolImplementation {
        @Test("creates from Foundation URL")
        func createFromURL() throws {
            #expect(try FileURL(url: #require(URL(string: "file:///foo/bar")))?.string == "file:///foo/bar")

            // Only valid for scheme `file`.
            #expect(try FileURL(url: #require(URL(string: "http://domain.com"))) == nil)
            #expect(try FileURL(url: #require(URL(string: "opds://domain.com"))) == nil)
        }

        @Test("creates from percent-encoded string")
        func createFromString() {
            #expect(FileURL(string: "file:///foo/bar")?.string == "file:///foo/bar")

            // Empty
            #expect(FileURL(string: "") == nil)
            #expect(FileURL(string: "file://") == nil)
            #expect(FileURL(string: "file://#fragment") == nil)
            // Not absolute
            #expect(FileURL(string: "path") == nil)
            // Only valid for scheme `file`.
            #expect(FileURL(string: "http://domain.com") == nil)
            #expect(FileURL(string: "opds://domain.com") == nil)
            // Query and fragment are ignored.
            #expect(FileURL(string: "file:///foo/bar?query#fragment")?.string == "file:///foo/bar")
            // The path is standardized.
            #expect(FileURL(string: "file:///foo/../bar/baz")?.string == "file:///bar/baz")
        }

        @Test("creates from an absolute file system path")
        func createFromPath() {
            // Empty
            #expect(FileURL(path: "/", isDirectory: false) == nil)
            // Absolute path
            #expect(FileURL(path: "/foo/bar", isDirectory: false)?.string == "file:///foo/bar")
            // Relative path
            #expect(FileURL(path: "foo/bar", isDirectory: false) == nil)
            // Containing special characters and ..
            #expect(FileURL(path: "/foo/../bar baz", isDirectory: false)?.string == "file:///bar%20baz")
            #expect(FileURL(path: "/../foo", isDirectory: false)?.string == "file:///foo")

            // Is directory
            #expect(FileURL(path: "/foo/bar/", isDirectory: false)?.string == "file:///foo/bar")
            #expect(FileURL(path: "/foo/bar", isDirectory: true)?.string == "file:///foo/bar/")
            #expect(FileURL(path: "/foo/bar/", isDirectory: true)?.string == "file:///foo/bar/")
        }

        @Test("url property returns Foundation URL")
        func url() {
            #expect(FileURL(string: "file:///foo/bar")?.url == URL(string: "file:///foo/bar"))
        }

        @Test("string property returns percent-encoded string")
        func string() {
            #expect(FileURL(string: "file:///foo/bar")?.string == "file:///foo/bar")
        }

        @Test("path is percent-decoded")
        func path() {
            #expect(FileURL(string: "file:///foo/bar%20baz")?.path == "/foo/bar baz")
            #expect(FileURL(string: "file:///foo/bar%20baz/")?.path == "/foo/bar baz/")
        }

        @Test("appendingPath appends a decoded path segment")
        func appendingPath() throws {
            var base = try #require(FileURL(string: "file:///foo/bar"))
            #expect(base.appendingPath("", isDirectory: false).string == "file:///foo/bar")
            #expect(base.appendingPath("baz/quz", isDirectory: false).string == "file:///foo/bar/baz/quz")
            #expect(base.appendingPath("/baz/quz", isDirectory: false).string == "file:///foo/bar/baz/quz")
            // The path is supposed to be decoded
            #expect(base.appendingPath("baz quz", isDirectory: false).string == "file:///foo/bar/baz%20quz")
            #expect(base.appendingPath("baz%20quz", isDirectory: false).string == "file:///foo/bar/baz%2520quz")
            // Directory
            #expect(base.appendingPath("baz/quz", isDirectory: true).string == "file:///foo/bar/baz/quz/")
            #expect(base.appendingPath("baz/quz/", isDirectory: true).string == "file:///foo/bar/baz/quz/")
            #expect(base.appendingPath("baz/quz", isDirectory: false).string == "file:///foo/bar/baz/quz")
            #expect(base.appendingPath("baz/quz/", isDirectory: false).string == "file:///foo/bar/baz/quz")

            // With trailing slash.
            base = try #require(FileURL(string: "file:///foo/bar/"))
            #expect(base.appendingPath("baz/quz", isDirectory: false).string == "file:///foo/bar/baz/quz")
        }

        @Test("pathSegments returns percent-decoded segments")
        func pathSegments() {
            #expect(FileURL(string: "file:///foo")?.pathSegments == ["foo"])
            #expect(FileURL(string: "file:///foo/bar%20baz")?.pathSegments == ["foo", "bar baz"])
            #expect(FileURL(string: "file:///foo/bar%20baz/")?.pathSegments == ["foo", "bar baz"])
            #expect(FileURL(string: "file:///foo/bar?query#fragment")?.pathSegments == ["foo", "bar"])
        }

        @Test("lastPathSegment returns the last decoded segment")
        func lastPathSegment() {
            #expect(FileURL(string: "file:///foo/bar%20baz")?.lastPathSegment == "bar baz")
            #expect(FileURL(string: "file:///foo/bar%20baz/")?.lastPathSegment == "bar baz")
            #expect(FileURL(string: "file:///foo/bar?query#fragment")?.lastPathSegment == "bar")
        }

        @Test("removingLastPathSegment removes the last path segment")
        func removingLastPathSegment() {
            #expect(FileURL(string: "file:///")?.removingLastPathSegment().string == "file:///")
            #expect(FileURL(string: "file:///foo")?.removingLastPathSegment().string == "file:///")
            #expect(FileURL(string: "file:///foo/bar")?.removingLastPathSegment().string == "file:///foo/")
        }

        @Test("pathExtension returns the file extension")
        func pathExtension() {
            #expect(FileURL(string: "file:///foo/bar.txt")?.pathExtension == "txt")
            #expect(FileURL(string: "file:///foo/bar")?.pathExtension == nil)
            #expect(FileURL(string: "file:///foo/bar/")?.pathExtension == nil)
            #expect(FileURL(string: "file:///foo/.hidden")?.pathExtension == nil)
        }

        @Test("replacingPathExtension replaces or removes the file extension")
        func replacingPathExtension() {
            #expect(FileURL(string: "file:///foo/bar")?.replacingPathExtension("xml").string == "file:///foo/bar.xml")
            #expect(FileURL(string: "file:///foo/bar.txt")?.replacingPathExtension("xml").string == "file:///foo/bar.xml")
            #expect(FileURL(string: "file:///foo/bar.txt")?.replacingPathExtension(nil).string == "file:///foo/bar")
            #expect(FileURL(string: "file:///foo/bar/")?.replacingPathExtension("xml").string == "file:///foo/bar/")
            #expect(FileURL(string: "file:///foo/bar/")?.replacingPathExtension(nil).string == "file:///foo/bar/")
        }

        @Test("query is always nil for file URLs")
        func query() {
            #expect(FileURL(string: "file:///foo/bar")?.query == nil)
            #expect(FileURL(string: "file:///foo/bar?param=quz%20baz")?.query == nil)
        }

        @Test("removingQuery is a no-op for file URLs")
        func removingQuery() {
            #expect(FileURL(string: "file:///foo/bar")?.removingQuery() == FileURL(string: "file:///foo/bar"))
            #expect(FileURL(string: "file:///foo/bar?param=quz%20baz")?.removingQuery() == FileURL(string: "file:///foo/bar"))
        }

        @Test("fragment is always nil for file URLs")
        func fragment() {
            // No fragment for a file URL.
            #expect(FileURL(string: "file:///foo/bar")?.fragment == nil)
            #expect(FileURL(string: "file:///foo/bar#quz%20baz")?.fragment == nil)
        }

        @Test("removingFragment is a no-op for file URLs")
        func removingFragment() {
            #expect(FileURL(string: "file:///foo/bar")?.removingFragment() == FileURL(string: "file:///foo/bar"))
            #expect(FileURL(string: "file:///foo/bar#quz%20baz")?.removingFragment() == FileURL(string: "file:///foo/bar"))
        }

        @Test("replacingFragment has no effect since file URLs always strip fragments")
        func replacingFragment() {
            // FileURL strips fragments on creation, so replacingFragment has no visible effect.
            #expect(FileURL(string: "file:///foo/bar")?.replacingFragment("baz").string == "file:///foo/bar")
            #expect(FileURL(string: "file:///foo/bar#old")?.replacingFragment("new").string == "file:///foo/bar")
            #expect(FileURL(string: "file:///foo/bar#quz%20baz")?.replacingFragment(nil) == FileURL(string: "file:///foo/bar"))
        }
    }

    struct AbsoluteURLImplementation {
        @Test("scheme is normalized to lowercase")
        func scheme() {
            #expect(FileURL(string: "file:///foo/bar")?.scheme == .file)
            #expect(FileURL(string: "FILE:///foo/bar")?.scheme == .file)
        }

        @Test("host is always nil for file URLs")
        func host() {
            #expect(FileURL(string: "file:///foo/bar")?.host == nil)
        }

        @Test("origin is always nil for file URLs")
        func origin() {
            #expect(FileURL(string: "file:///foo/bar")?.origin == nil)
        }

        @Test("resolves absolute URL as-is")
        func resolveAbsoluteURL() throws {
            let base = try #require(FileURL(string: "file:///foo/bar"))
            #expect(try base.resolve(#require(FileURL(string: "file:///foo")))?.string == "file:///foo")
            #expect(try base.resolve(#require(HTTPURL(string: "http://domain.com")))?.string == "http://domain.com")
            #expect(try base.resolve(#require(UnknownAbsoluteURL(string: "opds://other")))?.string == "opds://other")
        }

        @Test("resolves relative URL against this base")
        func resolveRelativeURL() throws {
            var base = try #require(FileURL(string: "file:///foo/bar"))
            #expect(try base.resolve(#require(RelativeURL(string: "quz/baz"))) == FileURL(string: "file:///foo/quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "../quz/baz"))) == FileURL(string: "file:///quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "/quz/baz"))) == FileURL(string: "file:///quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "#fragment"))) == FileURL(string: "file:///foo/bar#fragment"))

            // With trailing slash
            base = try #require(FileURL(string: "file:///foo/bar/"))
            #expect(try base.resolve(#require(RelativeURL(string: "quz/baz"))) == FileURL(string: "file:///foo/bar/quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "../quz/baz"))) == FileURL(string: "file:///foo/quz/baz"))
        }

        @Test("relativizes a URL against this base")
        func relativize() throws {
            var base = try #require(FileURL(string: "file:///foo"))
            #expect(try base.relativize(#require(AnyURL(string: "file:///foo"))) == nil)
            #expect(try base.relativize(#require(AnyURL(string: "file:///foo/quz/baz"))) == RelativeURL(string: "quz/baz"))
            #expect(try base.relativize(#require(AnyURL(string: "file:///quz/baz"))) == nil)

            // With trailing slash
            base = try #require(FileURL(string: "file:///foo/"))
            #expect(try base.relativize(#require(AnyURL(string: "file:///foo/quz/baz"))) == RelativeURL(string: "quz/baz"))
        }

        @Test("relative URL returns nil when relativized against a file base")
        func relativizeRelativeURL() throws {
            let base = try #require(FileURL(string: "file:///foo"))
            #expect(try base.relativize(#require(RelativeURL(string: "foo/bar"))) == nil)
        }

        @Test("URL with different scheme returns nil when relativized")
        func relativizeAbsoluteURLWithDifferentScheme() throws {
            let base = try #require(FileURL(string: "file:///foo"))
            #expect(try base.relativize(#require(HTTPURL(string: "https://host/foo/bar"))) == nil)
            #expect(try base.relativize(#require(UnknownAbsoluteURL(string: "opds://host/foo/bar"))) == nil)
        }

        @Test("isRelative is true for same scheme")
        func isRelative() throws {
            // Always relative if same scheme.
            let url = try #require(FileURL(string: "file:///foo/bar"))
            #expect(try url.isRelative(to: #require(FileURL(string: "file:///foo"))))
            #expect(try url.isRelative(to: #require(FileURL(string: "file:///foo/bar"))))
            #expect(try url.isRelative(to: #require(FileURL(string: "file:///foo/bar/baz"))))
            #expect(try url.isRelative(to: #require(FileURL(string: "file:///bar"))))

            // Different scheme
            #expect(try !url.isRelative(to: #require(UnknownAbsoluteURL(string: "other://host/foo"))))
            #expect(try !url.isRelative(to: #require(HTTPURL(string: "http://foo"))))
            // Relative path
            #expect(try !url.isRelative(to: #require(RelativeURL(path: "foo/bar"))))
        }
    }
}
