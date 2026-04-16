//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

enum UnknownAbsoluteURLTests {
    struct Equality {
        @Test("equal URLs compare as equal, fragments are significant")
        func equality() throws {
            #expect(UnknownAbsoluteURL(string: "opds://domain.com") == UnknownAbsoluteURL(string: "opds://domain.com"))
            #expect(
                try #require(UnknownAbsoluteURL(string: "opds://domain.com"))
                    != #require(UnknownAbsoluteURL(string: "opds://domain.com#fragment"))
            )
        }
    }

    struct URLProtocolImplementation {
        @Test("creates from Foundation URL")
        func createFromURL() throws {
            #expect(try UnknownAbsoluteURL(url: #require(URL(string: "opds://callback")))?.string == "opds://callback")
        }

        @Test("creates from percent-encoded string")
        func createFromString() {
            #expect(UnknownAbsoluteURL(string: "opds://callback")?.string == "opds://callback")

            // Empty
            #expect(UnknownAbsoluteURL(string: "")?.string == nil)
            // Not absolute
            #expect(UnknownAbsoluteURL(string: "path") == nil)
        }

        @Test("url property returns Foundation URL")
        func url() {
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar?query#fragment")?.url == URL(string: "opds://foo/bar?query#fragment"))
        }

        @Test("string property returns percent-encoded string")
        func string() {
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar?query#fragment")?.string == "opds://foo/bar?query#fragment")
        }

        @Test("path is percent-decoded")
        func path() {
            #expect(UnknownAbsoluteURL(string: "opds://host/foo/bar%20baz")?.path == "/foo/bar baz")
            #expect(UnknownAbsoluteURL(string: "opds://host/foo/bar%20baz/")?.path == "/foo/bar baz/")
            #expect(UnknownAbsoluteURL(string: "opds://host/foo/bar?query#fragment")?.path == "/foo/bar")
            #expect(UnknownAbsoluteURL(string: "opds://host#fragment")?.path == "")
            #expect(UnknownAbsoluteURL(string: "opds://host?query")?.path == "")
        }

        @Test("appendingPath appends a decoded path segment")
        func appendingPath() throws {
            var base = try #require(UnknownAbsoluteURL(string: "opds://foo/bar"))
            #expect(base.appendingPath("", isDirectory: false).string == "opds://foo/bar")
            #expect(base.appendingPath("baz/quz", isDirectory: false).string == "opds://foo/bar/baz/quz")
            #expect(base.appendingPath("/baz/quz", isDirectory: false).string == "opds://foo/bar/baz/quz")
            // The path is supposed to be decoded
            #expect(base.appendingPath("baz quz", isDirectory: false).string == "opds://foo/bar/baz%20quz")
            #expect(base.appendingPath("baz%20quz", isDirectory: false).string == "opds://foo/bar/baz%2520quz")
            // Directory
            #expect(base.appendingPath("baz/quz", isDirectory: true).string == "opds://foo/bar/baz/quz/")
            #expect(base.appendingPath("baz/quz/", isDirectory: true).string == "opds://foo/bar/baz/quz/")
            #expect(base.appendingPath("baz/quz", isDirectory: false).string == "opds://foo/bar/baz/quz")
            #expect(base.appendingPath("baz/quz/", isDirectory: false).string == "opds://foo/bar/baz/quz")

            // With trailing slash.
            base = try #require(UnknownAbsoluteURL(string: "opds://foo/bar/"))
            #expect(base.appendingPath("baz/quz", isDirectory: false).string == "opds://foo/bar/baz/quz")
        }

        @Test("pathSegments returns percent-decoded segments")
        func pathSegments() {
            #expect(UnknownAbsoluteURL(string: "opds://host/foo")?.pathSegments == ["foo"])
            // Segments are percent-decoded.
            #expect(UnknownAbsoluteURL(string: "opds://host/foo/bar%20baz")?.pathSegments == ["foo", "bar baz"])
            #expect(UnknownAbsoluteURL(string: "opds://host/foo/bar%20baz/")?.pathSegments == ["foo", "bar baz"])
            #expect(UnknownAbsoluteURL(string: "opds://host/foo/bar?query#fragment")?.pathSegments == ["foo", "bar"])
            #expect(UnknownAbsoluteURL(string: "opds://host#fragment")?.pathSegments == [])
            #expect(UnknownAbsoluteURL(string: "opds://host?query")?.pathSegments == [])
        }

        @Test("lastPathSegment returns the last decoded segment")
        func lastPathSegment() {
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar%20baz")?.lastPathSegment == "bar baz")
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar%20baz/")?.lastPathSegment == "bar baz")
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar?query#fragment")?.lastPathSegment == "bar")
            #expect(UnknownAbsoluteURL(string: "opds://#fragment")?.lastPathSegment == nil)
            #expect(UnknownAbsoluteURL(string: "opds://?query")?.lastPathSegment == nil)
        }

        @Test("removingLastPathSegment removes the last path segment")
        func removingLastPathSegment() {
            #expect(UnknownAbsoluteURL(string: "opds://")?.removingLastPathSegment().string == "opds://")
            #expect(UnknownAbsoluteURL(string: "opds://foo")?.removingLastPathSegment().string == "opds://foo")
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar")?.removingLastPathSegment().string == "opds://foo/")
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar/baz")?.removingLastPathSegment().string == "opds://foo/bar/")
        }

        @Test("pathExtension returns the file extension")
        func pathExtension() {
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar.txt")?.pathExtension == "txt")
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar")?.pathExtension == nil)
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar/")?.pathExtension == nil)
            #expect(UnknownAbsoluteURL(string: "opds://foo/.hidden")?.pathExtension == nil)
        }

        @Test("replacingPathExtension replaces or removes the file extension")
        func replacingPathExtension() {
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar")?.replacingPathExtension("xml").string == "opds://foo/bar.xml")
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar.txt")?.replacingPathExtension("xml").string == "opds://foo/bar.xml")
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar.txt")?.replacingPathExtension(nil).string == "opds://foo/bar")
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar/")?.replacingPathExtension("xml").string == "opds://foo/bar/")
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar/")?.replacingPathExtension(nil).string == "opds://foo/bar/")
            #expect(UnknownAbsoluteURL(string: "opds://foo")?.replacingPathExtension("xml").string == "opds://foo")
        }

        @Test("query returns parsed query parameters")
        func query() {
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar")?.query == nil)
            #expect(
                UnknownAbsoluteURL(string: "opds://foo/bar?param=quz%20baz")?.query
                    == URLQuery(parameters: [.init(name: "param", value: "quz baz")])
            )
        }

        @Test("removingQuery removes the query component")
        func removingQuery() {
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar")?.removingQuery() == UnknownAbsoluteURL(string: "opds://foo/bar"))
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar?param=quz%20baz")?.removingQuery() == UnknownAbsoluteURL(string: "opds://foo/bar"))
        }

        @Test("fragment is percent-decoded")
        func fragment() {
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar")?.fragment == nil)
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar#quz%20baz")?.fragment == "quz baz")
        }

        @Test("removingFragment removes the fragment component")
        func removingFragment() {
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar")?.removingFragment() == UnknownAbsoluteURL(string: "opds://foo/bar"))
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar#quz%20baz")?.removingFragment() == UnknownAbsoluteURL(string: "opds://foo/bar"))
        }

        @Test("replacingFragment sets or removes the fragment")
        func replacingFragment() {
            // Sets fragment on URL without one.
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar")?.replacingFragment("baz").string == "opds://foo/bar#baz")
            // Replaces existing fragment.
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar#old")?.replacingFragment("new").string == "opds://foo/bar#new")
            // Removing via nil matches removingFragment().
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar#quz%20baz")?.replacingFragment(nil) == UnknownAbsoluteURL(string: "opds://foo/bar"))
            // Fragment is percent-encoded.
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar")?.replacingFragment("quz baz").string == "opds://foo/bar#quz%20baz")
        }
    }

    struct AbsoluteURLImplementation {
        @Test("scheme is normalized to lowercase")
        func scheme() {
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar")?.scheme == URLScheme(rawValue: "opds"))
            #expect(UnknownAbsoluteURL(string: "OPDS://foo/bar")?.scheme == URLScheme(rawValue: "opds"))
        }

        @Test("host returns the hostname component")
        func host() {
            #expect(UnknownAbsoluteURL(string: "opds://")?.host == nil)
            #expect(UnknownAbsoluteURL(string: "opds:///")?.host == nil)
            #expect(UnknownAbsoluteURL(string: "opds://domain")?.host == "domain")
            #expect(UnknownAbsoluteURL(string: "opds://domain/path")?.host == "domain")
        }

        @Test("origin is always nil for unknown schemes")
        func origin() {
            #expect(UnknownAbsoluteURL(string: "opds://foo/bar")?.origin == nil)
        }

        @Test("resolves absolute URL as-is")
        func resolveAbsoluteURL() throws {
            let base = try #require(UnknownAbsoluteURL(string: "opds://host/foo/bar"))
            #expect(try base.resolve(#require(UnknownAbsoluteURL(string: "opds://other")))?.string == "opds://other")
            #expect(try base.resolve(#require(HTTPURL(string: "http://domain.com")))?.string == "http://domain.com")
            #expect(try base.resolve(#require(FileURL(string: "file:///foo")))?.string == "file:///foo")
        }

        @Test("resolves relative URL against this base")
        func resolveRelativeURL() throws {
            var base = try #require(UnknownAbsoluteURL(string: "opds://host/foo/bar"))
            #expect(try base.resolve(#require(RelativeURL(string: "quz/baz"))) == UnknownAbsoluteURL(string: "opds://host/foo/quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "../quz/baz"))) == UnknownAbsoluteURL(string: "opds://host/quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "/quz/baz"))) == UnknownAbsoluteURL(string: "opds://host/quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "#fragment"))) == UnknownAbsoluteURL(string: "opds://host/foo/bar#fragment"))

            // With trailing slash
            base = try #require(UnknownAbsoluteURL(string: "opds://host/foo/bar/"))
            #expect(try base.resolve(#require(RelativeURL(string: "quz/baz"))) == UnknownAbsoluteURL(string: "opds://host/foo/bar/quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "../quz/baz"))) == UnknownAbsoluteURL(string: "opds://host/foo/quz/baz"))
        }

        @Test("relativizes a URL against this base")
        func relativize() throws {
            var base = try #require(UnknownAbsoluteURL(string: "opds://host/foo"))
            #expect(try base.relativize(#require(AnyURL(string: "opds://host/foo"))) == nil)
            #expect(try base.relativize(#require(AnyURL(string: "opds://host/foo/quz/baz"))) == RelativeURL(string: "quz/baz"))
            #expect(try base.relativize(#require(AnyURL(string: "opds://host/foo#fragment"))) == RelativeURL(string: "#fragment"))
            #expect(try base.relativize(#require(AnyURL(string: "opds://host/quz/baz"))) == nil)
            #expect(try base.relativize(#require(AnyURL(string: "opds://host//foo/bar"))) == nil)

            // With trailing slash
            base = try #require(UnknownAbsoluteURL(string: "opds://host/foo/"))
            #expect(try base.relativize(#require(AnyURL(string: "opds://host/foo/quz/baz"))) == RelativeURL(string: "quz/baz"))
        }

        @Test("relative URL returns nil when relativized against an opds base")
        func relativizeRelativeURL() throws {
            let base = try #require(UnknownAbsoluteURL(string: "opds://host/foo"))
            #expect(try base.relativize(#require(RelativeURL(string: "host/foo/bar"))) == nil)
        }

        @Test("URL with different scheme returns nil when relativized")
        func relativizeAbsoluteURLWithDifferentScheme() throws {
            let base = try #require(UnknownAbsoluteURL(string: "opds://host/foo"))
            #expect(try base.relativize(#require(HTTPURL(string: "http://host/foo/bar"))) == nil)
            #expect(try base.relativize(#require(FileURL(string: "file://host/foo/bar"))) == nil)
        }

        @Test("isRelative is true for same scheme regardless of host")
        func isRelative() throws {
            // Always relative if same scheme.
            let url = try #require(UnknownAbsoluteURL(string: "opds://host/foo/bar"))
            #expect(try url.isRelative(to: #require(UnknownAbsoluteURL(string: "opds://host/foo"))))
            #expect(try url.isRelative(to: #require(UnknownAbsoluteURL(string: "opds://host/foo/bar"))))
            #expect(try url.isRelative(to: #require(UnknownAbsoluteURL(string: "opds://host/foo/bar/baz"))))
            #expect(try url.isRelative(to: #require(UnknownAbsoluteURL(string: "opds://host/bar"))))
            #expect(try url.isRelative(to: #require(UnknownAbsoluteURL(string: "opds://other-host"))))

            // Different scheme
            #expect(try !url.isRelative(to: #require(UnknownAbsoluteURL(string: "other://host/foo"))))
            #expect(try !url.isRelative(to: #require(HTTPURL(string: "http://foo"))))
            // Relative path
            #expect(try !url.isRelative(to: #require(RelativeURL(path: "foo/bar"))))
        }
    }
}
