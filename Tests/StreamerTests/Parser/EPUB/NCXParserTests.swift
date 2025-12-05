//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import XCTest

class NCXParserTests: XCTestCase {
    let fixtures = Fixtures(path: "Navigation Documents")

    func testParseTOC() {
        let document = parseNCX("nav")
        let sut = document.links(for: .tableOfContents)

        XCTAssertEqual(sut, [
            Link(href: "/base/ch1.xhtml", title: "Chapter 1"),
            Link(href: "/base/ch2.xhtml", title: "Chapter 2"),
            Link(href: "#", title: "Unlinked section with nested HTML elements", children: [
                Link(href: "/base/ssec1.xhtml", title: "Linked sub-section", children: [
                    Link(href: "/base/ssec1.xhtml#p1", title: "Paragraph"),
                ]),
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

    func parseNCX(_ name: String) -> NCXParser {
        let data = fixtures.data(at: "\(name).ncx")
        return NCXParser(data: data, at: RelativeURL(path: "/base/nav.xhtml")!)
    }
}
