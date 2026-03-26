//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class PublicationCollectionTests: XCTestCase {
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? PublicationCollection(json: [
                "links": [
                    ["href": "/link"],
                ],
            ]),
            PublicationCollection(links: [Link(href: "/link")])
        )
    }

    func testParseFullJSON() {
        XCTAssertEqual(
            try? PublicationCollection(json: [
                "metadata": [
                    "metadata1": "value",
                ],
                "links": [
                    ["href": "/link"],
                ],
                "sub1": [
                    "links": [
                        ["href": "/sublink"],
                    ],
                ],
                "sub2": [
                    ["href": "/sublink1"],
                    ["href": "/sublink2"],
                ],
                "sub3": [
                    [
                        "links": [
                            ["href": "/sublink3"],
                        ],
                    ],
                    [
                        "links": [
                            ["href": "/sublink4"],
                        ],
                    ],
                ],
            ] as JSONValue),
            PublicationCollection(
                metadata: [
                    "metadata1": "value",
                ],
                links: [Link(href: "/link")],
                subcollections: [
                    "sub1": [PublicationCollection(links: [Link(href: "/sublink")])],
                    "sub2": [PublicationCollection(links: [Link(href: "/sublink1"), Link(href: "/sublink2")])],
                    "sub3": [
                        PublicationCollection(links: [Link(href: "/sublink3")]),
                        PublicationCollection(links: [Link(href: "/sublink4")]),
                    ],
                ]
            )
        )
    }

    func testParseInvalidJSON() {
        XCTAssertThrowsError(try PublicationCollection(json: ""))
    }

    func testParseJSONArray() {
        XCTAssertEqual(
            PublicationCollection.makeCollections(json: [
                "ignored": ["value"],
                "sub1": [
                    "links": [
                        ["href": "/sublink"],
                    ],
                ],
                "sub2": [
                    ["href": "/sublink1"],
                    ["href": "/sublink2"],
                ],
                "sub3": [
                    [
                        "links": [
                            ["href": "/sublink3"],
                        ],
                    ],
                    [
                        "links": [
                            ["href": "/sublink4"],
                        ],
                    ],
                ],
            ] as JSONValue),
            [
                "sub1": [PublicationCollection(links: [Link(href: "/sublink")])],
                "sub2": [PublicationCollection(links: [Link(href: "/sublink1"), Link(href: "/sublink2")])],
                "sub3": [
                    PublicationCollection(links: [Link(href: "/sublink3")]),
                    PublicationCollection(links: [Link(href: "/sublink4")]),
                ],
            ]
        )
    }

    func testGetMinimalJSON() {
        XCTAssertEqual(
            PublicationCollection(links: [Link(href: "/link")]).jsonObject,
            [
                "links": [
                    ["href": "/link", "templated": false] as JSONValue,
                ],
            ]
        )
    }

    func testGetFullJSON() {
        XCTAssertEqual(
            PublicationCollection(
                metadata: [
                    "metadata1": "value",
                ],
                links: [Link(href: "/link")],
                subcollections: [
                    "sub1": [PublicationCollection(links: [Link(href: "/sublink")])],
                    "sub2": [PublicationCollection(links: [Link(href: "/sublink1"), Link(href: "/sublink2")])],
                    "sub3": [
                        PublicationCollection(links: [Link(href: "/sublink3")]),
                        PublicationCollection(links: [Link(href: "/sublink4")]),
                    ],
                ]
            ).jsonObject,
            [
                "metadata": [
                    "metadata1": "value",
                ],
                "links": [
                    ["href": "/link", "templated": false] as JSONValue,
                ],
                "sub1": [
                    "links": [
                        ["href": "/sublink", "templated": false] as JSONValue,
                    ],
                ],
                "sub2": [
                    "links": [
                        ["href": "/sublink1", "templated": false] as JSONValue,
                        ["href": "/sublink2", "templated": false],
                    ],
                ],
                "sub3": [
                    [
                        "links": [
                            ["href": "/sublink3", "templated": false] as JSONValue,
                        ],
                    ],
                    [
                        "links": [
                            ["href": "/sublink4", "templated": false],
                        ],
                    ],
                ],
            ] as [String: JSONValue]
        )
    }

    func testGetJSONArray() {
        XCTAssertEqual(
            PublicationCollection.serializeCollections([
                "sub1": [PublicationCollection(links: [Link(href: "/sublink")])],
                "sub2": [PublicationCollection(links: [Link(href: "/sublink1"), Link(href: "/sublink2")])],
                "sub3": [
                    PublicationCollection(links: [Link(href: "/sublink3")]),
                    PublicationCollection(links: [Link(href: "/sublink4")]),
                ],
            ]),
            [
                "sub1": [
                    "links": [
                        ["href": "/sublink", "templated": false] as JSONValue,
                    ],
                ],
                "sub2": [
                    "links": [
                        ["href": "/sublink1", "templated": false] as JSONValue,
                        ["href": "/sublink2", "templated": false],
                    ],
                ],
                "sub3": [
                    [
                        "links": [
                            ["href": "/sublink3", "templated": false] as JSONValue,
                        ],
                    ],
                    [
                        "links": [
                            ["href": "/sublink4", "templated": false],
                        ],
                    ],
                ],
            ] as [String: JSONValue]
        )
    }
}
