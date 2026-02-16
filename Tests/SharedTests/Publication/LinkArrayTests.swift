//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class LinkArrayTests: XCTestCase {
    /// Finds the first `Link` with given `rel`.
    func testFirstWithRel() {
        let links = [
            Link(href: "l1", rel: "other"),
            Link(href: "l2", rels: ["test", "other"]),
            Link(href: "l3", rel: "test"),
        ]

        XCTAssertEqual(links.firstWithRel("test")?.href, "l2")
    }

    /// Finds the first `Link` with given `rel` when none is found.
    func testFirstWithRelNotFound() {
        let links = [Link(href: "l1", rel: "other")]
        XCTAssertNil(links.firstWithRel("strawberry"))
    }

    /// Finds all the `Link` with given `rel`.
    func testFilterByRel() {
        let links = [
            Link(href: "l1", rel: "other"),
            Link(href: "l2", rels: ["test", "other"]),
            Link(href: "l3", rel: "test"),
        ]

        XCTAssertEqual(
            links.filterByRel("test"),
            [
                Link(href: "l2", rels: ["test", "other"]),
                Link(href: "l3", rel: "test"),
            ]
        )
    }

    /// Finds all the `Link` with given `rel` when none is found.
    func testFilterByRelNotFound() {
        let links = [Link(href: "l1", rel: "other")]
        XCTAssertEqual(links.filterByRel("strawberry").count, 0)
    }

    /// Finds the first `Link` with given `href`.
    func testFirstWithHREF() throws {
        let links = [
            Link(href: "l1"),
            Link(href: "l2"),
            Link(href: "l2", rel: "test"),
        ]

        XCTAssertEqual(try links.firstWithHREF(XCTUnwrap(AnyURL(string: "l2"))), Link(href: "l2"))
    }

    /// Finds the first `Link` with given `href` when none is found.
    func testFirstWithHREFNotFound() throws {
        let links = [Link(href: "l1")]
        XCTAssertNil(try links.firstWithHREF(XCTUnwrap(AnyURL(string: "unknown"))))
    }

    /// Finds the index of the first `Link` with given `href`.
    func testFirstIndexWithHREF() throws {
        let links = [
            Link(href: "l1"),
            Link(href: "l2"),
            Link(href: "l2", rel: "test"),
        ]

        XCTAssertEqual(try links.firstIndexWithHREF(XCTUnwrap(AnyURL(string: "l2"))), 1)
    }

    /// Finds the index of the first `Link` with given `href` when none is found.
    func testFirstIndexWithHREFNotFound() throws {
        let links = [Link(href: "l1")]
        XCTAssertNil(try links.firstIndexWithHREF(XCTUnwrap(AnyURL(string: "unknown"))))
    }

    /// Finds the first `Link` with a `type` matching the given `mediaType`.
    func testFirstWithMediaType() {
        let links = [
            Link(href: "l1", mediaType: .css),
            Link(href: "l2", mediaType: .html),
            Link(href: "l3", mediaType: .html),
        ]

        XCTAssertEqual(links.firstWithMediaType(.html)?.href, "l2")
    }

    /// Finds the first `Link` with a `type` matching the given `mediaType`, even if the `type` has
    /// extra parameters.
    func testFirstWithMediaTypeWithExtraParameter() throws {
        let links = try [
            Link(href: "l1", mediaType: XCTUnwrap(MediaType("text/html;charset=utf-8"))),
        ]

        XCTAssertEqual(links.firstWithMediaType(.html)?.href, "l1")
    }

    /// Finds the first `Link` with a `type` matching the given `mediaType`.
    func testFirstWithMediaTypeNotFound() {
        let links = [Link(href: "l1", mediaType: .css)]
        XCTAssertNil(links.firstWithMediaType(.html))
    }

    /// Finds all the `Link` with a `type` matching the given `mediaType`.
    func testFilterByMediaType() {
        let links = [
            Link(href: "l1", mediaType: .css),
            Link(href: "l2", mediaType: .html),
            Link(href: "l3", mediaType: .html),
        ]

        XCTAssertEqual(links.filterByMediaType(.html), [
            Link(href: "l2", mediaType: .html),
            Link(href: "l3", mediaType: .html),
        ])
    }

    /// Finds all the `Link` with a `type` matching the given `mediaType`, even if the `type` has
    /// extra parameters.
    func testFilterByMediaTypeWithExtraParameter() throws {
        let links = try [
            Link(href: "l1", mediaType: .css),
            Link(href: "l2", mediaType: .html),
            Link(href: "l1", mediaType: XCTUnwrap(MediaType("text/html;charset=utf-8"))),
        ]

        XCTAssertEqual(links.filterByMediaType(.html), try [
            Link(href: "l2", mediaType: .html),
            Link(href: "l1", mediaType: XCTUnwrap(MediaType("text/html;charset=utf-8"))),
        ])
    }

    /// Finds all the `Link` with a `type` matching the given `mediaType`, when none is found.
    func testFilterByMediaTypeNotFound() {
        let links = [Link(href: "l1", mediaType: .css)]
        XCTAssertEqual(links.filterByMediaType(.html).count, 0)
    }

    /// Finds all the `Link` with a `type` matching any of the given `mediaTypes`.
    func testFilterByMediaTypes() throws {
        let links = try [
            Link(href: "l1", mediaType: .css),
            Link(href: "l2", mediaType: XCTUnwrap(MediaType("text/html;charset=utf-8"))),
            Link(href: "l3", mediaType: .xml),
        ]

        XCTAssertEqual(links.filterByMediaTypes([.html, .xml]), try [
            Link(href: "l2", mediaType: XCTUnwrap(MediaType("text/html;charset=utf-8"))),
            Link(href: "l3", mediaType: .xml),
        ])
    }

    /// Checks if all the links are bitmaps.
    func testAllAreBitmap() {
        let links = [
            Link(href: "l1", mediaType: .png),
            Link(href: "l2", mediaType: .gif),
        ]

        XCTAssertTrue(links.allAreBitmap)
    }

    /// Checks if all the links are bitmaps, when it's not the case.
    func testAllAreBitmapFalse() {
        let links = [
            Link(href: "l1", mediaType: .png),
            Link(href: "l2", mediaType: .css),
        ]

        XCTAssertFalse(links.allAreBitmap)
    }

    /// Checks if all the links are audio clips.
    func testAllAreAudio() {
        let links = [
            Link(href: "l1", mediaType: .mp3),
            Link(href: "l2", mediaType: .aac),
        ]

        XCTAssertTrue(links.allAreAudio)
    }

    /// Checks if all the links are audio clips, when it's not the case.
    func testAllAreAudioFalse() {
        let links = [
            Link(href: "l1", mediaType: .mp3),
            Link(href: "l2", mediaType: .css),
        ]

        XCTAssertFalse(links.allAreAudio)
    }

    /// Checks if all the links are video clips.
    func testAllAreVideo() throws {
        let links = try [
            Link(href: "l1", mediaType: XCTUnwrap(MediaType("video/mp4"))),
            Link(href: "l2", mediaType: .webmVideo),
        ]

        XCTAssertTrue(links.allAreVideo)
    }

    /// Checks if all the links are video clips, when it's not the case.
    func testAllAreVideoFalse() {
        let links = [
            Link(href: "l1", mediaType: .mp4),
            Link(href: "l2", mediaType: .css),
        ]

        XCTAssertFalse(links.allAreVideo)
    }

    /// Checks if all the links are HTML documents.
    func testAllAreHTML() {
        let links = [
            Link(href: "l1", mediaType: .html),
            Link(href: "l2", mediaType: .xhtml),
        ]

        XCTAssertTrue(links.allAreHTML)
    }

    /// Checks if all the links are HTML documents, when it's not the case.
    func testAllAreHTMLFalse() {
        let links = [
            Link(href: "l1", mediaType: .html),
            Link(href: "l2", mediaType: .css),
        ]

        XCTAssertFalse(links.allAreHTML)
    }

    /// Checks if all the links match the given media type.
    func testAllMatchesMediaType() throws {
        let links = try [
            Link(href: "l1", mediaType: .css),
            Link(href: "l2", mediaType: XCTUnwrap(MediaType("text/css;charset=utf-8"))),
        ]

        XCTAssertTrue(links.allMatchingMediaType(.css))
    }

    /// Checks if all the links match the given media type when it's not the case.
    func testAllMatchesMediaTypeFalse() {
        let links = [
            Link(href: "l1", mediaType: .css),
            Link(href: "l2", mediaType: .text),
        ]

        XCTAssertFalse(links.allMatchingMediaType(.css))
    }

    /// Checks if all the links match any of the given media types.
    func testAllMatchesMediaTypes() {
        let links = [
            Link(href: "l1", mediaType: .html),
            Link(href: "l2", mediaType: .xml),
        ]

        XCTAssertTrue(links.allMatchingMediaTypes([.html, .xml]))
    }

    /// Checks if all the links match any of the given media types, when it's not the case.
    func testAllMatchesMediaTypesFalse() {
        let links = [
            Link(href: "l1", mediaType: .css),
            Link(href: "l2", mediaType: .html),
        ]

        XCTAssertFalse(links.allMatchingMediaTypes([.html, .xml]))
    }
}
