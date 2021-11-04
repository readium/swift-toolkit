//
//  LinkArrayTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 04/06/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class LinkArrayTests: XCTestCase {
    
    /// Finds the first `Link` with given `rel`.
    func testFirstWithRel() {
        let links = [
            Link(href: "l1", rel: "other"),
            Link(href: "l2", rels: ["test", "other"]),
            Link(href: "l3", rel: "test")
        ]
        
        XCTAssertEqual(links.first(withRel: "test")?.href, "l2")
    }
    
    /// Finds the first `Link` with given `rel` when none is found.
    func testFirstWithRelNotFound() {
        let links = [Link(href: "l1", rel: "other")]
        XCTAssertNil(links.first(withRel: "strawberry"))
    }
    
    /// Finds all the `Link` with given `rel`.
    func testFilterByRel() {
        let links = [
            Link(href: "l1", rel: "other"),
            Link(href: "l2", rels: ["test", "other"]),
            Link(href: "l3", rel: "test")
        ]
        
        XCTAssertEqual(
            links.filter(byRel: "test"),
            [
                Link(href: "l2", rels: ["test", "other"]),
                Link(href: "l3", rel: "test")
            ]
        )
    }
    
    /// Finds all the `Link` with given `rel` when none is found.
    func testFilterByRelNotFound() {
        let links = [Link(href: "l1", rel: "other")]
        XCTAssertEqual(links.filter(byRel: "strawberry").count, 0)
    }
    
    /// Finds the first `Link` with given `href`.
    func testFirstWithHREF() {
        let links = [
            Link(href: "l1"),
            Link(href: "l2"),
            Link(href: "l2", rel: "test")
        ]
        
        XCTAssertEqual(links.first(withHREF: "l2"), Link(href: "l2"))
    }
    
    /// Finds the first `Link` with given `href` when none is found.
    func testFirstWithHREFNotFound() {
        let links = [Link(href: "l1")]
        XCTAssertNil(links.first(withHREF: "unknown"))
    }
    
    /// Finds the index of the first `Link` with given `href`.
    func testFirstIndexWithHREF() {
        let links = [
            Link(href: "l1"),
            Link(href: "l2"),
            Link(href: "l2", rel: "test")
        ]
        
        XCTAssertEqual(links.firstIndex(withHREF: "l2"), 1)
    }
    
    /// Finds the index of the first `Link` with given `href` when none is found.
    func testFirstIndexWithHREFNotFound() {
        let links = [Link(href: "l1")]
        XCTAssertNil(links.firstIndex(withHREF: "unknown"))
    }

    /// Finds the first `Link` with a `type` matching the given `mediaType`.
    func testFirstWithMediaType() {
        let links = [
            Link(href: "l1", type: "text/css"),
            Link(href: "l2", type: "text/html"),
            Link(href: "l3", type: "text/html")
        ]
        
        XCTAssertEqual(links.first(withMediaType: .html)?.href, "l2")
    }

    /// Finds the first `Link` with a `type` matching the given `mediaType`, even if the `type` has
    /// extra parameters.
    func testFirstWithMediaTypeWithExtraParameter() {
        let links = [
            Link(href: "l1", type: "text/html;charset=utf-8")
        ]
        
        XCTAssertEqual(links.first(withMediaType: .html)?.href, "l1")
    }

    /// Finds the first `Link` with a `type` matching the given `mediaType`.
    func testFirstWithMediaTypeNotFound() {
        let links = [Link(href: "l1", type: "text/css")]
        XCTAssertNil(links.first(withMediaType: .html))
    }

    /// Finds all the `Link` with a `type` matching the given `mediaType`.
    func testFilterByMediaType() {
        let links = [
            Link(href: "l1", type: "text/css"),
            Link(href: "l2", type: "text/html"),
            Link(href: "l3", type: "text/html")
        ]
        
        XCTAssertEqual(links.filter(byMediaType: .html), [
            Link(href: "l2", type: "text/html"),
            Link(href: "l3", type: "text/html")
        ])
    }

    /// Finds all the `Link` with a `type` matching the given `mediaType`, even if the `type` has
    /// extra parameters.
    func testFilterByMediaTypeWithExtraParameter() {
        let links = [
            Link(href: "l1", type: "text/css"),
            Link(href: "l2", type: "text/html"),
            Link(href: "l1", type: "text/html;charset=utf-8")
        ]
        
        XCTAssertEqual(links.filter(byMediaType: .html), [
            Link(href: "l2", type: "text/html"),
            Link(href: "l1", type: "text/html;charset=utf-8")
        ])
    }
    
    /// Finds all the `Link` with a `type` matching the given `mediaType`, when none is found.
    func testFilterByMediaTypeNotFound() {
        let links = [Link(href: "l1", type: "text/css")]
        XCTAssertEqual(links.filter(byMediaType: .html).count, 0)
    }
    
    /// Finds all the `Link` with a `type` matching any of the given `mediaTypes`.
    func testFilterByMediaTypes() {
        let links = [
            Link(href: "l1", type: "text/css"),
            Link(href: "l2", type: "text/html;charset=utf-8"),
            Link(href: "l3", type: "application/xml")
        ]
        
        XCTAssertEqual(links.filter(byMediaTypes: [.html, .xml]), [
            Link(href: "l2", type: "text/html;charset=utf-8"),
            Link(href: "l3", type: "application/xml")
        ])
    }
    
    /// Checks if all the links are bitmaps.
    func testAllAreBitmap() {
        let links = [
            Link(href: "l1", type: "image/png"),
            Link(href: "l2", type: "image/gif")
        ]
        
        XCTAssertTrue(links.allAreBitmap)
    }
    
    /// Checks if all the links are bitmaps, when it's not the case.
    func testAllAreBitmapFalse() {
        let links = [
            Link(href: "l1", type: "image/png"),
            Link(href: "l2", type: "text/css")
        ]
        
        XCTAssertFalse(links.allAreBitmap)
    }
        
    /// Checks if all the links are audio clips.
    func testAllAreAudio() {
        let links = [
            Link(href: "l1", type: "audio/mpeg"),
            Link(href: "l2", type: "audio/aac")
        ]
        
        XCTAssertTrue(links.allAreAudio)
    }
    
    /// Checks if all the links are audio clips, when it's not the case.
    func testAllAreAudioFalse() {
        let links = [
            Link(href: "l1", type: "audio/mpeg"),
            Link(href: "l2", type: "text/css")
        ]
        
        XCTAssertFalse(links.allAreAudio)
    }
    
    /// Checks if all the links are video clips.
    func testAllAreVideo() {
        let links = [
            Link(href: "l1", type: "video/mp4"),
            Link(href: "l2", type: "video/webm")
        ]
        
        XCTAssertTrue(links.allAreVideo)
    }
    
    /// Checks if all the links are video clips, when it's not the case.
    func testAllAreVideoFalse() {
        let links = [
            Link(href: "l1", type: "video/mp4"),
            Link(href: "l2", type: "text/css")
        ]
        
        XCTAssertFalse(links.allAreVideo)
    }
    
    /// Checks if all the links are HTML documents.
    func testAllAreHTML() {
        let links = [
            Link(href: "l1", type: "text/html"),
            Link(href: "l2", type: "application/xhtml+xml")
        ]
        
        XCTAssertTrue(links.allAreHTML)
    }
    
    /// Checks if all the links are HTML documents, when it's not the case.
    func testAllAreHTMLFalse() {
        let links = [
            Link(href: "l1", type: "text/html"),
            Link(href: "l2", type: "text/css")
        ]
        
        XCTAssertFalse(links.allAreHTML)
    }
    
    /// Checks if all the links match the given media type.
    func testAllMatchesMediaType() {
        let links = [
            Link(href: "l1", type: "text/css"),
            Link(href: "l2", type: "text/css;charset=utf-8")
        ]
        
        XCTAssertTrue(links.all(matchMediaType: .css))
    }
    
    /// Checks if all the links match the given media type when it's not the case.
    func testAllMatchesMediaTypeFalse() {
        let links = [
            Link(href: "l1", type: "text/css"),
            Link(href: "l2", type: "text/plain")
        ]
        
        XCTAssertFalse(links.all(matchMediaType: .css))
    }
    
    /// Checks if all the links match any of the given media types.
    func testAllMatchesMediaTypes() {
        let links = [
            Link(href: "l1", type: "text/html"),
            Link(href: "l2", type: "application/xml")
        ]
        
        XCTAssertTrue(links.all(matchMediaTypes: [.html, .xml]))
    }
    
    /// Checks if all the links match any of the given media types, when it's not the case.
    func testAllMatchesMediaTypesFalse() {
        let links = [
            Link(href: "l1", type: "text/css"),
            Link(href: "l2", type: "text/html")
        ]
        
        XCTAssertFalse(links.all(matchMediaTypes: [.html, .xml]))
    }


}
