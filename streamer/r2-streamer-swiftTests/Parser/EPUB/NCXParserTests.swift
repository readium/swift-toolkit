//
//  NCXParserTests.swift
//  R2StreamerTests
//
//  Created by Mickaël Menu on 21.05.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
import R2Shared
@testable import R2Streamer


class NCXParserTests: XCTestCase {
    
    func testParseTOC() {
        let document = parseNCX("nav")
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
    
    func testParsePageList() {
        let document = parseNCX("nav")
        let sut = document.links(for: .pageList)
        
        XCTAssertEqual(sut, [
            Link(href: "/base/ch1.xhtml#page1", title: "1"),
            Link(href: "/base/ch1.xhtml#page2", title: "2"),
        ])
    }
    
    func testParseNotFound() {
        let document = parseNCX("nav-empty")
        let sut = document.links(for: .tableOfContents)

        XCTAssertEqual(sut, [])
    }

    
    // MARK: - Toolkit
    
    func parseNCX(_ name: String, type: String = "ncx") -> NCXParser {
        let url = SampleGenerator().getSamplesFileURL(named: "Navigation Documents/\(name)", ofType: type)!
        let data = try! Data(contentsOf: url)
        return NCXParser(data: data, at: "/base/nav.xhtml")
    }
    
}
