//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

enum AnyURLTests {
    struct Equality {
        @Test("equal URLs compare as equal")
        func equality() throws {
            #expect(AnyURL(string: "opds://domain.com") == AnyURL(string: "opds://domain.com"))
            #expect(
                try #require(AnyURL(string: "opds://domain.com"))
                    != #require(AnyURL(string: "https://domain.com"))
            )
            #expect(AnyURL(string: "dir/file") == AnyURL(string: "dir/file"))
            #expect(
                try #require(AnyURL(string: "dir/file"))
                    != #require(AnyURL(string: "dir/file#fragment"))
            )
        }
    }

    struct Creation {
        @Test("invalid URLs return nil")
        func createFromInvalidUrl() {
            #expect(AnyURL(string: "") == nil)
            #expect(AnyURL(string: "     ") == nil)
            #expect(AnyURL(string: "invalid character") == nil)
        }

        @Test("relative paths create relative AnyURL")
        func createFromRelativePath() throws {
            #expect(try AnyURL(string: "/foo/bar") == .relative(#require(RelativeURL(string: "/foo/bar"))))
            #expect(try AnyURL(string: "foo/bar") == .relative(#require(RelativeURL(string: "foo/bar"))))
            #expect(try AnyURL(string: "../bar") == .relative(#require(RelativeURL(string: "../bar"))))
        }

        @Test("absolute URLs create absolute AnyURL")
        func createFromAbsoluteURLs() throws {
            #expect(try AnyURL(string: "file:///foo/bar") == .absolute(#require(FileURL(string: "file:///foo/bar"))))
            #expect(try AnyURL(string: "http://host/foo/bar") == .absolute(#require(HTTPURL(string: "http://host/foo/bar"))))
            #expect(try AnyURL(string: "opds://host/foo/bar") == .absolute(#require(UnknownAbsoluteURL(string: "opds://host/foo/bar"))))
        }

        @Test("legacy HREFs are normalized and percent-encoded")
        func createFromLegacyHREF() throws {
            #expect(try AnyURL(legacyHREF: "dir/chapter.xhtml") == .relative(#require(RelativeURL(string: "dir/chapter.xhtml"))))
            // Starting slash is removed.
            #expect(try AnyURL(legacyHREF: "/dir/chapter.xhtml") == .relative(#require(RelativeURL(string: "dir/chapter.xhtml"))))
            // Special characters are percent-encoded.
            #expect(try AnyURL(legacyHREF: "/dir/per%cent.xhtml") == .relative(#require(RelativeURL(string: "dir/per%25cent.xhtml"))))
            #expect(try AnyURL(legacyHREF: "/barré.xhtml") == .relative(#require(RelativeURL(string: "barr%C3%A9.xhtml"))))
            #expect(try AnyURL(legacyHREF: "/spa ce.xhtml") == .relative(#require(RelativeURL(string: "spa%20ce.xhtml"))))
            // We assume that a relative path is percent-decoded.
            #expect(try AnyURL(legacyHREF: "/spa%20ce.xhtml") == .relative(#require(RelativeURL(string: "spa%2520ce.xhtml"))))
            // Some special characters are authorized in a path.
            #expect(try AnyURL(legacyHREF: "/$&+,/=@") == .relative(#require(RelativeURL(string: "$&+,/=@"))))
            // Valid absolute URL are left untouched.
            #expect(
                try AnyURL(legacyHREF: "http://domain.com/a%20book?page=3")
                    == .absolute(#require(HTTPURL(string: "http://domain.com/a%20book?page=3")))
            )
        }
    }

    struct Resolution {
        @Test("resolves relative URLs against an HTTP base")
        func resolveHTTPURL() throws {
            var base = try #require(AnyURL(string: "http://example.com/foo/bar"))
            #expect(try base.resolve(#require(AnyURL(string: "quz/baz")))?.string == "http://example.com/foo/quz/baz")
            #expect(try base.resolve(#require(AnyURL(string: "../quz/baz")))?.string == "http://example.com/quz/baz")
            #expect(try base.resolve(#require(AnyURL(string: "/quz/baz")))?.string == "http://example.com/quz/baz")
            #expect(try base.resolve(#require(AnyURL(string: "#fragment")))?.string == "http://example.com/foo/bar#fragment")
            #expect(try base.resolve(#require(AnyURL(string: "file:///foo/bar")))?.string == "file:///foo/bar")

            // With trailing slash
            base = try #require(AnyURL(string: "http://example.com/foo/bar/"))
            #expect(try base.resolve(#require(AnyURL(string: "quz/baz")))?.string == "http://example.com/foo/bar/quz/baz")
            #expect(try base.resolve(#require(AnyURL(string: "../quz/baz")))?.string == "http://example.com/foo/quz/baz")
        }

        @Test("resolves relative URLs against a file base")
        func resolveFileURL() throws {
            var base = try #require(AnyURL(string: "file:///root/foo/bar"))
            #expect(try base.resolve(#require(AnyURL(string: "quz")))?.string == "file:///root/foo/quz")
            #expect(try base.resolve(#require(AnyURL(string: "quz/baz")))?.string == "file:///root/foo/quz/baz")
            #expect(try base.resolve(#require(AnyURL(string: "../quz")))?.string == "file:///root/quz")

            // With trailing slash
            base = try #require(AnyURL(string: "file:///root/foo/bar/"))
            #expect(try base.resolve(#require(AnyURL(string: "quz/baz")))?.string == "file:///root/foo/bar/quz/baz")
            #expect(try base.resolve(#require(AnyURL(string: "../quz")))?.string == "file:///root/foo/quz")
        }

        @Test("resolves two relative URLs")
        func resolveTwoRelativeURLs() throws {
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
    }

    struct Relativization {
        @Test("relativizes URLs against an HTTP base")
        func relativizeHTTPURL() throws {
            var base = try #require(AnyURL(string: "http://example.com/foo"))
            #expect(try base.relativize(#require(AnyURL(string: "http://example.com/foo/quz/baz")))?.string == "quz/baz")
            #expect(try base.relativize(#require(AnyURL(string: "http://example.com/foo#fragment")))?.string == "#fragment")

            // With trailing slash
            base = try #require(AnyURL(string: "http://example.com/foo/"))
            #expect(try base.relativize(#require(AnyURL(string: "http://example.com/foo/quz/baz")))?.string == "quz/baz")
        }

        @Test("relativizes URLs against a file base")
        func relativizeFileURL() throws {
            var base = try #require(AnyURL(string: "file:///root/foo"))
            #expect(try base.relativize(#require(AnyURL(string: "file:///root/foo/quz/baz")))?.string == "quz/baz")
            #expect(try base.relativize(#require(AnyURL(string: "http://example.com/foo/bar"))) == nil)

            // With trailing slash
            base = try #require(AnyURL(string: "file:///root/foo/"))
            #expect(try base.relativize(#require(AnyURL(string: "file:///root/foo/quz/baz")))?.string == "quz/baz")
        }

        @Test("relativizes two relative URLs")
        func relativizeTwoRelativeURLs() throws {
            var base = try #require(AnyURL(string: "foo"))
            #expect(try base.relativize(#require(AnyURL(string: "foo/quz/baz")))?.string == "quz/baz")
            #expect(try base.relativize(#require(AnyURL(string: "foo#fragment")))?.string == "#fragment")
            #expect(try base.relativize(#require(AnyURL(string: "quz/baz"))) == nil)
            #expect(try base.relativize(#require(AnyURL(string: "/quz/baz"))) == nil)
            #expect(try base.relativize(#require(AnyURL(string: "http://example.com/foo/bar"))) == nil)

            // With trailing slash
            base = try #require(AnyURL(string: "foo/"))
            #expect(try base.relativize(#require(AnyURL(string: "foo/quz/baz")))?.string == "quz/baz")

            // With starting slash
            base = try #require(AnyURL(string: "/foo"))
            #expect(try base.relativize(#require(AnyURL(string: "/foo/quz/baz")))?.string == "quz/baz")
            #expect(try base.relativize(#require(AnyURL(string: "/quz/baz"))) == nil)
        }
    }

    struct Normalization {
        @Test("scheme is lowercased, path is decoded, relative segments are resolved")
        func normalized() {
            // Scheme is lower case.
            #expect(AnyURL(string: "HTTP://example.com")?.normalized.string == "http://example.com")

            // Path is percent-decoded.
            #expect(AnyURL(string: "HTTP://example.com/c%27est%20valide")?.normalized.string == "http://example.com/c'est%20valide")
            #expect(AnyURL(string: "c%27est%20valide")?.normalized.string == "c'est%20valide")

            // Relative paths are resolved.
            #expect(AnyURL(string: "http://example.com/foo/./bar/../baz")?.normalized.string == "http://example.com/foo/baz")
            #expect(AnyURL(string: "foo/./bar/../baz")?.normalized.string == "foo/baz")
            #expect(AnyURL(string: "foo/./bar/../../../baz")?.normalized.string == "../baz")

            // Trailing slash is kept.
            #expect(AnyURL(string: "http://example.com/foo/")?.normalized.string == "http://example.com/foo/")
            #expect(AnyURL(string: "foo/")?.normalized.string == "foo/")

            // The other components are left as-is.
            #expect(
                AnyURL(string: "http://user:password@example.com:443/foo?b=b&a=a#fragment")?.normalized.string
                    == "http://user:password@example.com:443/foo?b=b&a=a#fragment"
            )
        }
    }

    struct Fragment {
        @Test("replacingFragment sets or removes the fragment")
        func replacingFragment() {
            // Sets fragment on URL without one.
            #expect(AnyURL(string: "foo/bar")?.replacingFragment("baz").string == "foo/bar#baz")
            // Replaces existing fragment.
            #expect(AnyURL(string: "foo/bar#old")?.replacingFragment("new").string == "foo/bar#new")
            // Removing via nil matches removingFragment().
            #expect(AnyURL(string: "foo/bar#quz%20baz")?.replacingFragment(nil) == AnyURL(string: "foo/bar"))
            // Fragment is percent-encoded.
            #expect(AnyURL(string: "foo/bar")?.replacingFragment("quz baz").string == "foo/bar#quz%20baz")
        }
    }
}
