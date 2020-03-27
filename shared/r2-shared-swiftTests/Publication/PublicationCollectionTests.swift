//
//  PublicationCollectionTests.swift
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

class PublicationCollectionTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? PublicationCollection(role: "guided", json: [
                "links": [
                    ["href": "/link"]
                ]
            ]),
            PublicationCollection(role: "guided", links: [Link(href: "/link")])
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? PublicationCollection(role: "guided", json: [
                "metadata": [
                    "metadata1": "value"
                ],
                "links": [
                    ["href": "/link"]
                ],
                "sub1": [
                    "links": [
                        ["href": "/sublink"]
                    ]
                ],
                "sub2": [
                    ["href": "/sublink1"],
                    ["href": "/sublink2"]
                ],
                "sub3": [
                    [
                        "links": [
                            ["href": "/sublink3"]
                        ]
                    ],
                    [
                        "links": [
                            ["href": "/sublink4"]
                        ]
                    ]
                ]
            ]),
            PublicationCollection(
                role: "guided",
                metadata: [
                    "metadata1": "value"
                ],
                links: [Link(href: "/link")],
                otherCollections: [
                    PublicationCollection(role: "sub1", links: [Link(href: "/sublink")]),
                    PublicationCollection(role: "sub2", links: [Link(href: "/sublink1"), Link(href: "/sublink2")]),
                    PublicationCollection(role: "sub3", links: [Link(href: "/sublink3")]),
                    PublicationCollection(role: "sub3", links: [Link(href: "/sublink4")]),
                ]
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try PublicationCollection(role: "guided", json: ""))
    }

    func testParseJSONArray() {
        XCTAssertEqual(
            [PublicationCollection](json: [
                "ignored": [ "value" ],
                "sub1": [
                    "links": [
                        ["href": "/sublink"]
                    ]
                ],
                "sub2": [
                    ["href": "/sublink1"],
                    ["href": "/sublink2"]
                ],
                "sub3": [
                    [
                        "links": [
                            ["href": "/sublink3"]
                        ]
                    ],
                    [
                        "links": [
                            ["href": "/sublink4"]
                        ]
                    ]
                ]
            ]),
            [
                PublicationCollection(role: "sub1", links: [Link(href: "/sublink")]),
                PublicationCollection(role: "sub2", links: [Link(href: "/sublink1"), Link(href: "/sublink2")]),
                PublicationCollection(role: "sub3", links: [Link(href: "/sublink3")]),
                PublicationCollection(role: "sub3", links: [Link(href: "/sublink4")]),
            ]
        )
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(
            PublicationCollection(role: "guided", links: [Link(href: "/link")]).json,
            [
                "links": [
                    ["href": "/link", "templated": false]
                ]
            ]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            PublicationCollection(
                role: "guided",
                metadata: [
                    "metadata1": "value"
                ],
                links: [Link(href: "/link")],
                otherCollections: [
                    PublicationCollection(role: "sub1", links: [Link(href: "/sublink")]),
                    PublicationCollection(role: "sub2", links: [Link(href: "/sublink1"), Link(href: "/sublink2")]),
                    PublicationCollection(role: "sub3", links: [Link(href: "/sublink3")]),
                    PublicationCollection(role: "sub3", links: [Link(href: "/sublink4")]),
                    ]
            ).json,
            [
                "metadata": [
                    "metadata1": "value"
                ],
                "links": [
                    ["href": "/link", "templated": false]
                ],
                "sub1": [
                    "links": [
                        ["href": "/sublink", "templated": false]
                    ]
                ],
                "sub2": [
                    "links": [
                        ["href": "/sublink1", "templated": false],
                        ["href": "/sublink2", "templated": false]
                    ]
                ],
                "sub3": [
                    [
                        "links": [
                            ["href": "/sublink3", "templated": false]
                        ]
                    ],
                    [
                        "links": [
                            ["href": "/sublink4", "templated": false]
                        ]
                    ]
                ]
            ]
        )
    }
    
    func testGetJSONArray() {
        AssertJSONEqual(
            [
                PublicationCollection(role: "sub1", links: [Link(href: "/sublink")]),
                PublicationCollection(role: "sub2", links: [Link(href: "/sublink1"), Link(href: "/sublink2")]),
                PublicationCollection(role: "sub3", links: [Link(href: "/sublink3")]),
                PublicationCollection(role: "sub3", links: [Link(href: "/sublink4")]),
            ].json,
            [
                "sub1": [
                    "links": [
                        ["href": "/sublink", "templated": false]
                    ]
                ],
                "sub2": [
                    "links": [
                        ["href": "/sublink1", "templated": false],
                        ["href": "/sublink2", "templated": false]
                    ]
                ],
                "sub3": [
                    [
                        "links": [
                            ["href": "/sublink3", "templated": false]
                        ]
                    ],
                    [
                        "links": [
                            ["href": "/sublink4", "templated": false]
                        ]
                    ]
                ]
            ]
        )
    }

}
