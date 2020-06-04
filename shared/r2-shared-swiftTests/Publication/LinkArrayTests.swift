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
    func testFirstWithHref() {
        let links = [
            Link(href: "l1"),
            Link(href: "l2"),
            Link(href: "l2", rel: "test")
        ]
        
        XCTAssertEqual(links.first(withHref: "l2"), Link(href: "l2"))
    }
    
    /// Finds the first `Link` with given `href` when none is found.
    func testFirstWithHrefNotFound() {
        let links = [Link(href: "l1")]
        XCTAssertNil(links.first(withHref: "unknown"))
    }
    
    /// Finds the index of the first `Link` with given `href`.
    func testFirstIndexWithHref() {
        let links = [
            Link(href: "l1"),
            Link(href: "l2"),
            Link(href: "l2", rel: "test")
        ]
        
        XCTAssertEqual(links.firstIndex(withHref: "l2"), 1)
    }
    
    /// Finds the index of the first `Link` with given `href` when none is found.
    func testFirstIndexWithHrefNotFound() {
        let links = [Link(href: "l1")]
        XCTAssertNil(links.firstIndex(withHref: "unknown"))
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
    func testFilterWithMediaType() {
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
    func testFilterWithMediaTypeWithExtraParameter() {
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
    func testFilterWithMediaTypeNotFound() {
        let links = [Link(href: "l1", type: "text/css")]
        XCTAssertEqual(links.filter(byMediaType: .html).count, 0)
    }
    
    /// Checks if all the links are bitmaps.
    func testAllIsBitmap() {
        let links = [
            Link(href: "l1", type: "image/png"),
            Link(href: "l2", type: "image/gif")
        ]
        
        XCTAssertTrue(links.allIsBitmap)
    }
    
    /// Checks if all the links are bitmaps, when it's not the case.
    func testAllIsBitmapFalse() {
        let links = [
            Link(href: "l1", type: "image/png"),
            Link(href: "l2", type: "text/css")
        ]
        
        XCTAssertFalse(links.allIsBitmap)
    }
        
    /// Checks if all the links are audio clips.
    func testAllIsAudio() {
        let links = [
            Link(href: "l1", type: "audio/mpeg"),
            Link(href: "l2", type: "audio/aac")
        ]
        
        XCTAssertTrue(links.allIsAudio)
    }
    
    /// Checks if all the links are audio clips, when it's not the case.
    func testAllIsAudioFalse() {
        let links = [
            Link(href: "l1", type: "audio/mpeg"),
            Link(href: "l2", type: "text/css")
        ]
        
        XCTAssertFalse(links.allIsAudio)
    }
    
    /// Checks if all the links are video clips.
    func testAllIsVideo() {
        let links = [
            Link(href: "l1", type: "video/mp4"),
            Link(href: "l2", type: "video/webm")
        ]
        
        XCTAssertTrue(links.allIsVideo)
    }
    
    /// Checks if all the links are video clips, when it's not the case.
    func testAllIsVideoFalse() {
        let links = [
            Link(href: "l1", type: "video/mp4"),
            Link(href: "l2", type: "text/css")
        ]
        
        XCTAssertFalse(links.allIsVideo)
    }
    
    /// Checks if all the links are HTML documents.
    func testAllIsHTML() {
        let links = [
            Link(href: "l1", type: "text/html"),
            Link(href: "l2", type: "application/xhtml+xml")
        ]
        
        XCTAssertTrue(links.allIsHTML)
    }
    
    /// Checks if all the links are HTML documents, when it's not the case.
    func testAllIsHTMLFalse() {
        let links = [
            Link(href: "l1", type: "text/html"),
            Link(href: "l2", type: "text/css")
        ]
        
        XCTAssertFalse(links.allIsHTML)
    }
    
    /// Checks if all the links match the given media type.
    func testAllMatchesMediaType() {
        let links = [
            Link(href: "l1", type: "text/css"),
            Link(href: "l2", type: "text/css;charset=utf-8")
        ]
        
        XCTAssertTrue(links.all(matchesMediaType: .css))
    }
    
    /// Checks if all the links match the given media type when it's not the case.
    func testAllMatchesMediaTypeFalse() {
        let links = [
            Link(href: "l1", type: "text/css"),
            Link(href: "l2", type: "text/plain")
        ]
        
        XCTAssertFalse(links.all(matchesMediaType: .css))
    }
    
    /// Checks if all the links match any of the given media types.
    func testAllMatchesMediaTypes() {
        let links = [
            Link(href: "l1", type: "text/html"),
            Link(href: "l2", type: "application/xml")
        ]
        
        XCTAssertTrue(links.all(matchesMediaTypes: [.html, .xml]))
    }
    
    /// Checks if all the links match any of the given media types, when it's not the case.
    func testAllMatchesMediaTypesFalse() {
        let links = [
            Link(href: "l1", type: "text/css"),
            Link(href: "l2", type: "text/html")
        ]
        
        XCTAssertFalse(links.all(matchesMediaTypes: [.html, .xml]))
    }


}
