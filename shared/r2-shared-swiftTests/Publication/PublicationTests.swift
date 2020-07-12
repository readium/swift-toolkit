//
//  PublicationTests.swift
//  r2-shared-swiftTests
//
//  Created by Mickaël Menu on 11.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class PublicationTests: XCTestCase {

    func testGetJSON() {
        XCTAssertEqual(
            Publication(
                manifest: Manifest(
                    metadata: Metadata(title: "Title"),
                    links: [Link(href: "/manifest.json", rels: ["self"])],
                    readingOrder: [Link(href: "/chap1.html", type: "text/html")]
                )
            ).jsonManifest,
            serializeJSONString([
                "metadata": ["title": "Title", "readingProgression": "auto"],
                "links": [
                    ["href": "/manifest.json", "rel": ["self"], "templated": false]
                ],
                "readingOrder": [
                    ["href": "/chap1.html", "type": "text/html", "templated": false]
                ]
            ])
        )
    }
    
    func testBaseURL() {
        XCTAssertEqual(
            makePublication(links: [
                Link(href: "http://host/folder/manifest.json", rel: "self")
            ]).baseURL,
            URL(string: "http://host/folder/")!
        )
    }
    
    func testBaseURLMissing() {
        XCTAssertNil(
            makePublication(links: [
                Link(href: "http://host/folder/manifest.json")
            ]).baseURL
        )
    }
    
    func testBaseURLRoot() {
        XCTAssertEqual(
            makePublication(links: [
                Link(href: "http://host/manifest.json", rel: "self")
            ]).baseURL,
            URL(string: "http://host/")!
        )
    }
    
    func testLinkWithHREFInReadingOrder() {
        XCTAssertEqual(
            makePublication(readingOrder: [
                Link(href: "l1"),
                Link(href: "l2")
            ]).link(withHREF: "l2")?.href,
            "l2"
        )
    }
    
    func testLinkWithHREFInLinks() {
        XCTAssertEqual(
            makePublication(links: [
                Link(href: "l1"),
                Link(href: "l2")
            ]).link(withHREF: "l2")?.href,
            "l2"
        )
    }
    
    func testLinkWithHREFInResources() {
        XCTAssertEqual(
            makePublication(resources: [
                Link(href: "l1"),
                Link(href: "l2")
            ]).link(withHREF: "l2")?.href,
            "l2"
        )
    }
    
    func testLinkWithHREFInAlternate() {
        XCTAssertEqual(
            makePublication(resources: [
                Link(href: "l1", alternates: [
                    Link(href: "l2", alternates: [
                        Link(href: "l3")
                    ])
                ])
            ]).link(withHREF: "l3")?.href,
            "l3"
        )
    }
    
    func testLinkWithHREFInChildren() {
        XCTAssertEqual(
            makePublication(resources: [
                Link(href: "l1", children: [
                    Link(href: "l2", children: [
                        Link(href: "l3")
                    ])
                ])
            ]).link(withHREF: "l3")?.href,
            "l3"
        )
    }
    
    func testLinkWithHREFIgnoresQuery() {
        let publication = makePublication(links: [
            Link(href: "l1?q=a"),
            Link(href: "l2")
        ])
        
        XCTAssertEqual(publication.link(withHREF: "l1?q=a")?.href, "l1?q=a")
        XCTAssertEqual(publication.link(withHREF: "l2?q=b")?.href, "l2")
    }
    
    func testLinkWithHREFIgnoresAnchor() {
        let publication = makePublication(links: [
            Link(href: "l1#a"),
            Link(href: "l2")
        ])
        
        XCTAssertEqual(publication.link(withHREF: "l1#a")?.href, "l1#a")
        XCTAssertEqual(publication.link(withHREF: "l2#b")?.href, "l2")
    }
    
    func testLinkWithRelInReadingOrder() {
        XCTAssertEqual(
            makePublication(readingOrder: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1")
            ]).link(withRel: "rel1")?.href,
            "l2"
        )
    }
    
    func testLinkWithRelInLinks() {
        XCTAssertEqual(
            makePublication(links: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1")
            ]).link(withRel: "rel1")?.href,
            "l2"
        )
    }
    
    func testLinkWithRelInResources() {
        XCTAssertEqual(
            makePublication(resources: [
                Link(href: "l1"),
                Link(href: "l2", rel: "rel1")
            ]).link(withRel: "rel1")?.href,
            "l2"
        )
    }
    
    func testLinksWithRel() {
        XCTAssertEqual(
            makePublication(
                links: [
                    Link(href: "l1"),
                    Link(href: "l2", rel: "rel1")
                ],
                readingOrder: [
                    Link(href: "l3"),
                    Link(href: "l4", rel: "rel1")
                ],
                resources: [
                    Link(href: "l5", alternates: [
                        Link(href: "alternate", rel: "rel1")
                    ]),
                    Link(href: "l6", rel: "rel1")
                ]
            ).links(withRel: "rel1"),
            [
                Link(href: "l4", rel: "rel1"),
                Link(href: "l6", rel: "rel1"),
                Link(href: "l2", rel: "rel1")
            ]
        )
    }
    
    func testLinksWithRelEmpty() {
        XCTAssertEqual(
            makePublication(resources: [
                Link(href: "l1"),
                Link(href: "l2")
            ]).links(withRel: "rel1"),
            []
        )
    }

    private func makePublication(metadata: Metadata = Metadata(title: ""), links: [Link] = [], readingOrder: [Link] = [], resources: [Link] = []) -> Publication {
        return Publication(manifest: Manifest(metadata: metadata, links: links, readingOrder: readingOrder, resources: resources))
    }

}
