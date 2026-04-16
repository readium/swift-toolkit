//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

enum HTTPURLTests {
    struct Equality {
        @Test("equal URLs compare as equal, fragments are significant")
        func equality() throws {
            #expect(HTTPURL(string: "http://domain.com") == HTTPURL(string: "http://domain.com"))
            #expect(
                try #require(HTTPURL(string: "http://domain.com"))
                    != #require(HTTPURL(string: "http://domain.com#fragment"))
            )
        }
    }

    struct URLProtocolImplementation {
        @Test("creates from Foundation URL")
        func createFromURL() throws {
            #expect(try HTTPURL(url: #require(URL(string: "http://domain.com")))?.string == "http://domain.com")
            #expect(try HTTPURL(url: #require(URL(string: "https://domain.com")))?.string == "https://domain.com")

            // Only valid for schemes `http` or `https`.
            #expect(try HTTPURL(url: #require(URL(string: "file://domain.com"))) == nil)
            #expect(try HTTPURL(url: #require(URL(string: "opds://domain.com"))) == nil)
        }

        @Test("creates from percent-encoded string")
        func createFromString() {
            #expect(HTTPURL(string: "http://domain.com")?.string == "http://domain.com")

            // Empty
            #expect(HTTPURL(string: "")?.string == nil)
            // Not absolute
            #expect(HTTPURL(string: "path") == nil)
            // Only valid for schemes `http` or `https`.
            #expect(HTTPURL(string: "file://domain.com") == nil)
            #expect(HTTPURL(string: "opds://domain.com") == nil)
        }

        @Test("url property returns Foundation URL")
        func url() {
            #expect(HTTPURL(string: "http://foo/bar?query#fragment")?.url == URL(string: "http://foo/bar?query#fragment"))
        }

        @Test("string property returns percent-encoded string")
        func string() {
            #expect(HTTPURL(string: "http://foo/bar?query#fragment")?.string == "http://foo/bar?query#fragment")
        }

        @Test("path is percent-decoded")
        func path() {
            #expect(HTTPURL(string: "http://host/foo/bar%20baz")?.path == "/foo/bar baz")
            #expect(HTTPURL(string: "http://host/foo/bar%20baz/")?.path == "/foo/bar baz/")
            #expect(HTTPURL(string: "http://host/foo/bar?query#fragment")?.path == "/foo/bar")
            #expect(HTTPURL(string: "http://host#fragment")?.path == "")
            #expect(HTTPURL(string: "http://host?query")?.path == "")
        }

        @Test("appendingPath appends a decoded path segment")
        func appendingPath() throws {
            var base = try #require(HTTPURL(string: "http://foo/bar"))
            #expect(base.appendingPath("", isDirectory: false).string == "http://foo/bar")
            #expect(base.appendingPath("baz/quz", isDirectory: false).string == "http://foo/bar/baz/quz")
            #expect(base.appendingPath("/baz/quz", isDirectory: false).string == "http://foo/bar/baz/quz")
            // The path is supposed to be decoded
            #expect(base.appendingPath("baz quz", isDirectory: false).string == "http://foo/bar/baz%20quz")
            #expect(base.appendingPath("baz%20quz", isDirectory: false).string == "http://foo/bar/baz%2520quz")
            // Directory
            #expect(base.appendingPath("baz/quz", isDirectory: true).string == "http://foo/bar/baz/quz/")
            #expect(base.appendingPath("baz/quz/", isDirectory: true).string == "http://foo/bar/baz/quz/")
            #expect(base.appendingPath("baz/quz", isDirectory: false).string == "http://foo/bar/baz/quz")
            #expect(base.appendingPath("baz/quz/", isDirectory: false).string == "http://foo/bar/baz/quz")

            // With trailing slash.
            base = try #require(HTTPURL(string: "http://foo/bar/"))
            #expect(base.appendingPath("baz/quz", isDirectory: false).string == "http://foo/bar/baz/quz")
        }

        @Test("pathSegments returns percent-decoded segments")
        func pathSegments() {
            #expect(HTTPURL(string: "http://host/foo")?.pathSegments == ["foo"])
            // Segments are percent-decoded.
            #expect(HTTPURL(string: "http://host/foo/bar%20baz")?.pathSegments == ["foo", "bar baz"])
            #expect(HTTPURL(string: "http://host/foo/bar%20baz/")?.pathSegments == ["foo", "bar baz"])
            #expect(HTTPURL(string: "http://host/foo/bar?query#fragment")?.pathSegments == ["foo", "bar"])
            #expect(HTTPURL(string: "http://host#fragment")?.pathSegments == [])
            #expect(HTTPURL(string: "http://host?query")?.pathSegments == [])
        }

        @Test("lastPathSegment returns the last decoded segment")
        func lastPathSegment() {
            #expect(HTTPURL(string: "http://foo/bar%20baz")?.lastPathSegment == "bar baz")
            #expect(HTTPURL(string: "http://foo/bar%20baz/")?.lastPathSegment == "bar baz")
            #expect(HTTPURL(string: "http://foo/bar?query#fragment")?.lastPathSegment == "bar")
            #expect(HTTPURL(string: "http://#fragment")?.lastPathSegment == nil)
            #expect(HTTPURL(string: "http://?query")?.lastPathSegment == nil)
        }

        @Test("removingLastPathSegment removes the last path segment")
        func removingLastPathSegment() {
            #expect(HTTPURL(string: "http://")?.removingLastPathSegment().string == "http://")
            #expect(HTTPURL(string: "http://foo")?.removingLastPathSegment().string == "http://foo")
            #expect(HTTPURL(string: "http://foo/bar")?.removingLastPathSegment().string == "http://foo/")
            #expect(HTTPURL(string: "http://foo/bar/baz")?.removingLastPathSegment().string == "http://foo/bar/")
        }

        @Test("pathExtension returns the file extension")
        func pathExtension() {
            #expect(HTTPURL(string: "http://foo/bar.txt")?.pathExtension == "txt")
            #expect(HTTPURL(string: "http://foo/bar")?.pathExtension == nil)
            #expect(HTTPURL(string: "http://foo/bar/")?.pathExtension == nil)
            #expect(HTTPURL(string: "http://foo/.hidden")?.pathExtension == nil)
        }

        @Test("replacingPathExtension replaces or removes the file extension")
        func replacingPathExtension() {
            #expect(HTTPURL(string: "http://foo/bar")?.replacingPathExtension("xml").string == "http://foo/bar.xml")
            #expect(HTTPURL(string: "http://foo/bar.txt")?.replacingPathExtension("xml").string == "http://foo/bar.xml")
            #expect(HTTPURL(string: "http://foo/bar.txt")?.replacingPathExtension(nil).string == "http://foo/bar")
            #expect(HTTPURL(string: "http://foo/bar/")?.replacingPathExtension("xml").string == "http://foo/bar/")
            #expect(HTTPURL(string: "http://foo/bar/")?.replacingPathExtension(nil).string == "http://foo/bar/")
            #expect(HTTPURL(string: "http://foo")?.replacingPathExtension("xml").string == "http://foo")
        }

        @Test("query returns parsed query parameters")
        func query() {
            #expect(HTTPURL(string: "http://foo/bar")?.query == nil)
            #expect(
                HTTPURL(string: "http://foo/bar?param=quz%20baz")?.query
                    == URLQuery(parameters: [.init(name: "param", value: "quz baz")])
            )
        }

        @Test("removingQuery removes the query component")
        func removingQuery() {
            #expect(HTTPURL(string: "http://foo/bar")?.removingQuery() == HTTPURL(string: "http://foo/bar"))
            #expect(HTTPURL(string: "http://foo/bar?param=quz%20baz")?.removingQuery() == HTTPURL(string: "http://foo/bar"))
        }

        @Test("fragment is percent-decoded")
        func fragment() {
            #expect(HTTPURL(string: "http://foo/bar")?.fragment == nil)
            #expect(HTTPURL(string: "http://foo/bar#quz%20baz")?.fragment == "quz baz")
        }

        @Test("removingFragment removes the fragment component")
        func removingFragment() {
            #expect(HTTPURL(string: "http://foo/bar")?.removingFragment() == HTTPURL(string: "http://foo/bar"))
            #expect(HTTPURL(string: "http://foo/bar#quz%20baz")?.removingFragment() == HTTPURL(string: "http://foo/bar"))
        }

        @Test("replacingFragment sets or removes the fragment")
        func replacingFragment() {
            // Sets fragment on URL without one.
            #expect(HTTPURL(string: "http://foo/bar")?.replacingFragment("baz").string == "http://foo/bar#baz")
            // Replaces existing fragment.
            #expect(HTTPURL(string: "http://foo/bar#old")?.replacingFragment("new").string == "http://foo/bar#new")
            // Removing via nil matches removingFragment().
            #expect(HTTPURL(string: "http://foo/bar#quz%20baz")?.replacingFragment(nil) == HTTPURL(string: "http://foo/bar"))
            // Fragment is percent-encoded.
            #expect(HTTPURL(string: "http://foo/bar")?.replacingFragment("quz baz").string == "http://foo/bar#quz%20baz")
        }
    }

    struct AbsoluteURLImplementation {
        @Test("scheme is normalized to lowercase")
        func scheme() {
            #expect(HTTPURL(string: "http://foo/bar")?.scheme == .http)
            #expect(HTTPURL(string: "HTTP://foo/bar")?.scheme == .http)
            #expect(HTTPURL(string: "https://foo/bar")?.scheme == .https)
        }

        @Test("host returns the hostname component")
        func host() {
            #expect(HTTPURL(string: "http://")?.host == nil)
            #expect(HTTPURL(string: "http:///")?.host == nil)
            #expect(HTTPURL(string: "http://domain")?.host == "domain")
            #expect(HTTPURL(string: "http://domain/path")?.host == "domain")
        }

        @Test("origin returns scheme and host")
        func origin() {
            #expect(HTTPURL(string: "HTTP://foo/bar")?.origin == "http://foo")
            #expect(HTTPURL(string: "https://foo:443/bar")?.origin == "https://foo:443")
        }

        @Test("resolves absolute URL as-is")
        func resolveAbsoluteURL() throws {
            let base = try #require(HTTPURL(string: "http://host/foo/bar"))
            #expect(try base.resolve(#require(HTTPURL(string: "http://domain.com")))?.string == "http://domain.com")
            #expect(try base.resolve(#require(UnknownAbsoluteURL(string: "opds://other")))?.string == "opds://other")
            #expect(try base.resolve(#require(FileURL(string: "file:///foo")))?.string == "file:///foo")
        }

        @Test("resolves relative URL against this base")
        func resolveRelativeURL() throws {
            var base = try #require(HTTPURL(string: "http://host/foo/bar"))
            #expect(try base.resolve(#require(RelativeURL(string: "quz/baz"))) == HTTPURL(string: "http://host/foo/quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "../quz/baz"))) == HTTPURL(string: "http://host/quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "/quz/baz"))) == HTTPURL(string: "http://host/quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "#fragment"))) == HTTPURL(string: "http://host/foo/bar#fragment"))

            // With trailing slash
            base = try #require(HTTPURL(string: "http://host/foo/bar/"))
            #expect(try base.resolve(#require(RelativeURL(string: "quz/baz"))) == HTTPURL(string: "http://host/foo/bar/quz/baz"))
            #expect(try base.resolve(#require(RelativeURL(string: "../quz/baz"))) == HTTPURL(string: "http://host/foo/quz/baz"))
        }

        @Test("relativizes a URL against this base")
        func relativize() throws {
            var base = try #require(HTTPURL(string: "http://host/foo"))
            #expect(try base.relativize(#require(AnyURL(string: "http://host/foo"))) == nil)
            #expect(try base.relativize(#require(AnyURL(string: "http://host/foo/quz/baz"))) == RelativeURL(string: "quz/baz"))
            #expect(try base.relativize(#require(AnyURL(string: "http://host/foo#fragment"))) == RelativeURL(string: "#fragment"))
            #expect(try base.relativize(#require(AnyURL(string: "http://host/quz/baz"))) == nil)
            #expect(try base.relativize(#require(AnyURL(string: "http://host//foo/bar"))) == nil)

            // With trailing slash
            base = try #require(HTTPURL(string: "http://host/foo/"))
            #expect(try base.relativize(#require(AnyURL(string: "http://host/foo/quz/baz"))) == RelativeURL(string: "quz/baz"))
        }

        @Test("relative URL returns nil when relativized against an HTTP base")
        func relativizeRelativeURL() throws {
            let base = try #require(HTTPURL(string: "http://host/foo"))
            #expect(try base.relativize(#require(RelativeURL(string: "host/foo/bar"))) == nil)
        }

        @Test("URL with different scheme returns nil when relativized")
        func relativizeAbsoluteURLWithDifferentScheme() throws {
            let base = try #require(HTTPURL(string: "http://host/foo"))
            #expect(try base.relativize(#require(HTTPURL(string: "https://host/foo/bar"))) == nil)
            #expect(try base.relativize(#require(FileURL(string: "file://host/foo/bar"))) == nil)
        }

        @Test("isRelative is true only for same origin")
        func isRelative() throws {
            let url = try #require(HTTPURL(string: "http://host/foo/bar"))
            #expect(try url.isRelative(to: #require(HTTPURL(string: "http://host/foo"))))
            #expect(try url.isRelative(to: #require(HTTPURL(string: "http://host/foo/bar"))))
            #expect(try url.isRelative(to: #require(HTTPURL(string: "http://host/foo/bar/baz"))))
            #expect(try url.isRelative(to: #require(HTTPURL(string: "http://host/bar"))))

            // Different scheme
            #expect(try !url.isRelative(to: #require(UnknownAbsoluteURL(string: "other://host/foo"))))
            #expect(try !url.isRelative(to: #require(HTTPURL(string: "https://host/foo"))))
            // Different host
            #expect(try !url.isRelative(to: #require(HTTPURL(string: "http://foo"))))
            // Relative path
            #expect(try !url.isRelative(to: #require(RelativeURL(path: "foo/bar"))))
        }
    }
}
