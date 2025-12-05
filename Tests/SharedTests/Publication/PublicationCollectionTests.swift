//
//  Copyright 2025 Readium Foundation. All rights reserved.
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
            ] as [String: Any]),
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
            ] as [String: Any]),
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
        AssertJSONEqual(
            PublicationCollection(links: [Link(href: "/link")]).json,
            [
                "links": [
                    ["href": "/link", "templated": false] as [String: Any],
                ],
            ]
        )
    }

    func testGetFullJSON() {
        AssertJSONEqual(
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
            ).json,
            [
                "metadata": [
                    "metadata1": "value",
                ],
                "links": [
                    ["href": "/link", "templated": false] as [String: Any],
                ],
                "sub1": [
                    "links": [
                        ["href": "/sublink", "templated": false] as [String: Any],
                    ],
                ],
                "sub2": [
                    "links": [
                        ["href": "/sublink1", "templated": false] as [String: Any],
                        ["href": "/sublink2", "templated": false],
                    ],
                ],
                "sub3": [
                    [
                        "links": [
                            ["href": "/sublink3", "templated": false] as [String: Any],
                        ],
                    ],
                    [
                        "links": [
                            ["href": "/sublink4", "templated": false],
                        ],
                    ],
                ],
            ] as [String: Any]
        )
    }

    func testGetJSONArray() {
        AssertJSONEqual(
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
                        ["href": "/sublink", "templated": false] as [String: Any],
                    ],
                ],
                "sub2": [
                    "links": [
                        ["href": "/sublink1", "templated": false] as [String: Any],
                        ["href": "/sublink2", "templated": false],
                    ],
                ],
                "sub3": [
                    [
                        "links": [
                            ["href": "/sublink3", "templated": false] as [String: Any],
                        ],
                    ],
                    [
                        "links": [
                            ["href": "/sublink4", "templated": false],
                        ],
                    ],
                ],
            ] as [String: Any]
        )
    }
}
