//
//  NavigationDocumentParserTests.swift
//  R2StreamerTests
//
//  Created by Mickaël Menu on 16.05.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
import R2Shared
@testable import R2Streamer


class NavigationDocumentParserTests: XCTestCase {
    
    func testParseTOC() {
        let document = parseNavDocument("nav")
        let sut = document.links(for: .tableOfContents)
        
        XCTAssertEqual(sut, [
            Link(href: "/base/ch1.xhtml", title: "Chapter 1"),
            Link(href: "/base/ch2.xhtml", title: "Chapter 2"),
            Link(href: "#", title: "Unlinked section with nested HTML elements", children: [
                Link(href: "/base/ssec1.xhtml", title: "Linked sub-section", children: [
                    Link(href: "/base/ssec1.xhtml#p1", title: "Paragraph"),
                ])
            ]),
            Link(href: "/base/dir/ch3.xhtml", title: "A link with nested HTML elements"),
            Link(href: "/ch4.xhtml", title: "A link with newlines splitting the text"),
        ])
    }
    
    func testParseLandmarks() {
        let document = parseNavDocument("nav")
        let sut = document.links(for: .landmarks)
        
        XCTAssertEqual(sut, [
            Link(href: "/base/nav.xhtml#toc", title: "Table of Contents"),
            Link(href: "/base/ch1.xhtml", title: "Begin Reading"),
        ])
    }
    
    func testParseNotFound() {
        let document = parseNavDocument("nav")
        let sut = document.links(for: .listOfVideos)
        
        XCTAssertEqual(sut, [])
    }
    
    func testParseTOCWithSection() {
        let document = parseNavDocument("nav-section")
        let sut = document.links(for: .tableOfContents)
        
        XCTAssertEqual(sut, [
            Link(href: "/base/ch1.xhtml", title: "Chapter 1"),
            Link(href: "/base/ch2.xhtml", title: "Chapter 2")
        ])
    }

    func testParseLandmarksWithSection() {
        let document = parseNavDocument("nav-section")
        let sut = document.links(for: .landmarks)
        
        XCTAssertEqual(sut, [
            Link(href: "/base/nav.xhtml#toc", title: "Table of Contents"),
            Link(href: "/base/ch1.xhtml", title: "Begin Reading"),
        ])
    }

    
    // MARK: - Toolkit

    func parseNavDocument(_ name: String, type: String = "xhtml") -> NavigationDocumentParser {
        let url = SampleGenerator().getSamplesFileURL(named: "Navigation Documents/\(name)", ofType: type)!
        let data = try! Data(contentsOf: url)
        return NavigationDocumentParser(data: data, at: "/base/nav.xhtml")
    }
    
}
