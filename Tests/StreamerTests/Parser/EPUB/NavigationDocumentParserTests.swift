//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import Testing

struct NavigationDocumentParserTests {
    let fixtures = Fixtures(path: "Navigation Documents")

    @Test func parseTOC() {
        let document = parseNavDocument("nav")
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

    @Test func parseLandmarks() {
        let document = parseNavDocument("nav")
        let sut = document.links(for: .landmarks)

        #expect(sut == [
            Link(href: "/base/nav.xhtml#toc", title: "Table of Contents", rel: .contents),
            Link(href: "/base/ch1.xhtml", title: "Begin Reading", rel: .start),
        ])
    }

    @Test func parseNotFound() {
        let document = parseNavDocument("nav")
        let sut = document.links(for: .listOfVideos)

        #expect(sut == [])
    }

    @Test func parseTOCWithSection() {
        let document = parseNavDocument("nav-section")
        let sut = document.links(for: .tableOfContents)

        #expect(sut == [
            Link(href: "/base/ch1.xhtml", title: "Chapter 1"),
            Link(href: "/base/ch2.xhtml", title: "Chapter 2"),
        ])
    }

    @Test func parseLandmarksWithSection() {
        let document = parseNavDocument("nav-section")
        let sut = document.links(for: .landmarks)

        #expect(sut == [
            Link(href: "/base/cover.xhtml", title: "Cover", rel: .cover),
            Link(href: "/base/nav.xhtml#toc", title: "Table of Contents", rel: .contents),
            Link(href: "/base/ch1.xhtml", title: "Begin Reading", rel: .start),
            Link(href: "/base/index.xhtml", title: "Index", rel: "http://idpf.org/epub/vocab/structure/#index"),
            Link(href: "/base/glossary.xhtml", title: "Glossary", rel: "http://idpf.org/epub/vocab/structure/#glossary"),
        ])
    }

    /// HREFs that are not percent-encoded (they contain spaces) but carry URI
    /// fragments and queries must keep the `#`/`?` as separators instead of
    /// encoding them into the path.
    @Test func parseTOCWithUnencodedHREFs() {
        let document = parseNavDocument("nav-unencoded")
        let sut = document.links(for: .tableOfContents)

        #expect(sut == [
            Link(href: "/base/content/chapter%20one%201.xhtml#fragment-01", title: "Chapter 1"),
            Link(href: "/base/content/chapter%20two%202.xhtml?title=intro#fragment-02", title: "Chapter 2"),
            Link(href: "/content/chapter%20one%201.xhtml#fragment-03", title: "Chapter 1, again"),
        ])
    }

    // MARK: - Toolkit

    func parseNavDocument(_ name: String) -> NavigationDocumentParser {
        let data = fixtures.data(at: "\(name).xhtml")
        return NavigationDocumentParser(data: data, at: RelativeURL(path: "/base/nav.xhtml")!)
    }
}
