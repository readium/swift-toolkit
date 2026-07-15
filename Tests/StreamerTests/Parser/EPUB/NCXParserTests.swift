//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import Testing

struct NCXParserTests {
    let fixtures = Fixtures(path: "Navigation Documents")

    @Test func parseTOC() {
        let document = parseNCX("nav")
        let sut = document.links(for: .tableOfContents)

        #expect(sut == [
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

    @Test func parsePageList() {
        let document = parseNCX("nav")
        let sut = document.links(for: .pageList)

        #expect(sut == [
            Link(href: "/base/ch1.xhtml#page1", title: "1"),
            Link(href: "/base/ch1.xhtml#page2", title: "2"),
        ])
    }

    @Test func parseNotFound() {
        let document = parseNCX("nav-empty")
        let sut = document.links(for: .tableOfContents)

        #expect(sut == [])
    }

    /// `src` values that are not percent-encoded (they contain spaces) but
    /// carry URI fragments and queries must keep the `#`/`?` as separators
    /// instead of encoding them into the path.
    @Test func parseTOCWithUnencodedHREFs() {
        let document = parseNCX("nav-unencoded")
        let sut = document.links(for: .tableOfContents)

        #expect(sut == [
            Link(href: "/base/content/chapter%20one%201.xhtml#fragment-01", title: "Chapter 1"),
            Link(href: "/base/content/chapter%20two%202.xhtml?title=intro#fragment-02", title: "Chapter 2"),
            Link(href: "/content/chapter%20one%201.xhtml#fragment-03", title: "Chapter 1, again"),
        ])
    }

    // MARK: - Toolkit

    func parseNCX(_ name: String) -> NCXParser {
        let data = fixtures.data(at: "\(name).ncx")
        return NCXParser(data: data, at: RelativeURL(path: "/base/nav.xhtml")!)
    }
}
