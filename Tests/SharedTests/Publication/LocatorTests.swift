//
//  LocatorTests.swift
//  r2-shared-swiftTests
//
//  Created by Mickaël Menu on 20.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class LocatorTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Locator(json: [
                "href": "http://locator",
                "type": "text/html"
            ]),
            Locator(
                href: "http://locator",
                type: "text/html"
            )
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? Locator(json: [
                "href": "http://locator",
                "type": "text/html",
                "title": "My Locator",
                "locations": [
                    "position": 42
                ],
                "text": [
                    "highlight": "Excerpt"
                ]
            ]),
            Locator(
                href: "http://locator",
                type: "text/html",
                title: "My Locator",
                locations: .init(position: 42),
                text: .init(highlight: "Excerpt")
            )
        )
    }
    
    func testParseNilJSON() {
        XCTAssertNil(try Locator(json: nil))
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Locator(json: ""))
    }
    
    func testParseJSONArray() {
        XCTAssertEqual(
            [Locator](json: [
                ["href": "loc1", "type": "text/html"],
                ["href": "loc2", "type": "text/html"],
            ]),
            [
                Locator(href: "loc1", type: "text/html"),
                Locator(href: "loc2", type: "text/html")
            ]
        )
    }
    
    func testParseJSONArrayWhenNil() {
        XCTAssertEqual([Locator](json: nil), [])
    }
    
    func testMakeFromFullLink() {
        XCTAssertEqual(
            Locator(link: Link(
                href: "http://locator",
                type: "text/html",
                title: "Link title"
            )),
            Locator(
                href: "http://locator",
                type: "text/html",
                title: "Link title"
            )
        )
    }
    
    func testMakeFromMinimalLink() {
        XCTAssertEqual(
            Locator(link: Link(
                href: "http://locator"
            )),
            Locator(
                href: "http://locator",
                type: "",
                title: nil
            )
        )
    }
    
    func testMakeFromLinkWithFragment() {
        XCTAssertEqual(
            Locator(link: Link(
                href: "http://locator#page=42"
            )),
            Locator(
                href: "http://locator",
                type: "",
                locations: .init(fragments: ["page=42"])
            )
        )
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            Locator(
                href: "http://locator",
                type: "text/html"
            ).json,
            [
                "href": "http://locator",
                "type": "text/html"
            ]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            Locator(
                href: "http://locator",
                type: "text/html",
                title: "My Locator",
                locations: .init(position: 42),
                text: .init(highlight: "Excerpt")
            ).json,
            [
                "href": "http://locator",
                "type": "text/html",
                "title": "My Locator",
                "locations": [
                    "position": 42
                ],
                "text": [
                    "highlight": "Excerpt"
                ]
            ]
        )
    }
    
    func testGetJSONArray() {
        AssertJSONEqual(
            [
                Locator(href: "loc1", type: "text/html"),
                Locator(href: "loc2", type: "text/html")
            ].json,
            [
                ["href": "loc1", "type": "text/html"],
                ["href": "loc2", "type": "text/html"],
            ]
        )
    }
    
    func testCopy() {
        let locator = Locator(
            href: "http://locator",
            type: "text/html",
            title: "My Locator",
            locations: .init(position: 42),
            text: .init(highlight: "Excerpt")
        )
        AssertJSONEqual(locator.json, locator.copy().json)
        
        let copy = locator.copy(
            title: "edited",
            locations: { $0.progression = 0.4 },
            text: { $0.before = "before" }
        )

        AssertJSONEqual(
            copy.json,
            [
                "href": "http://locator",
                "type": "text/html",
                "title": "edited",
                "locations": [
                    "position": 42,
                    "progression": 0.4
                ],
                "text": [
                    "before": "before",
                    "highlight": "Excerpt",
                ]
            ]
        )
    }
    
}


class LocatorLocationsTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Locator.Locations(json: [
                "position": 42
            ]),
            Locator.Locations(
                position: 42
            )
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? Locator.Locations(json: [
                "fragments": ["p=4", "frag34"],
                "progression": 0.74,
                "totalProgression": 25.32,
                "position": 42,
                "other": "other-location"
            ]),
            Locator.Locations(
                fragments: ["p=4", "frag34"],
                progression: 0.74,
                totalProgression: 25.32,
                position: 42,
                otherLocations: ["other": "other-location"]
            )
        )
    }
    
    func testParseSingleFragment() {
        XCTAssertEqual(
            try? Locator.Locations(json: [
                "fragment": "frag34",
            ]),
            Locator.Locations(
                fragments: ["frag34"]
            )
        )
    }
    
    func testParseEmptyJSON() {
        XCTAssertEqual(
            try Locator.Locations(json: [:]),
            Locator.Locations()
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Locator.Locations(json: ""))
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(
            Locator.Locations(
                position: 42
            ).json as Any,
            [
                "position": 42
            ]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            Locator.Locations(
                fragments: ["p=4", "frag34"],
                progression: 0.74,
                totalProgression: 25.32,
                position: 42,
                otherLocations: ["other": "other-location"]
            ).json as Any,
            [
                "fragments": ["p=4", "frag34"],
                "progression": 0.74,
                "totalProgression": 25.32,
                "position": 42,
                "other": "other-location"
            ]
        )
    }
    
}


class LocatorTextTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Locator.Text(json: [
                "after": "Text after"
            ]),
            Locator.Text(
                after: "Text after"
            )
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? Locator.Text(json: [
                "after": "Text after",
                "before": "Text before",
                "highlight": "Highlighted text"
            ]),
            Locator.Text(
                after: "Text after",
                before: "Text before",
                highlight: "Highlighted text"
            )
        )
    }
    
    func testParseEmptyJSON() {
        XCTAssertEqual(
            try Locator.Text(json: [:]),
            Locator.Text()
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Locator.Text(json: ""))
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(
            Locator.Text(
                after: "Text after"
            ).json as Any,
            [
                "after": "Text after"
            ]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            Locator.Text(
                after: "Text after",
                before: "Text before",
                highlight: "Highlighted text"
            ).json as Any,
            [
                "after": "Text after",
                "before": "Text before",
                "highlight": "Highlighted text"
            ]
        )
    }
    
}

class LocatorCollectionTests: XCTestCase {

    func testParseMinimalJSON() {
        XCTAssertEqual(
            _LocatorCollection(json: [:]),
            _LocatorCollection()
        )
    }

    func testParseFullJSON() {
        XCTAssertEqual(
            _LocatorCollection(json: [
                "metadata": [
                    "title": [
                        "en": "Searching <riddle> in Alice in Wonderlands - Page 1",
                        "fr": "Recherche <riddle> dans Alice in Wonderlands – Page 1"
                    ],
                    "numberOfItems": 3,
                    "extraMetadata": "value"
                ],
                "links": [
                    ["rel": "self", "href": "/978-1503222687/search?query=apple", "type": "application/vnd.readium.locators+json"],
                    ["rel": "next", "href": "/978-1503222687/search?query=apple&page=2", "type": "application/vnd.readium.locators+json"]
                ],
                "locators": [
                    [
                        "href": "/978-1503222687/chap7.html",
                        "type": "application/xhtml+xml",
                        "locations": [
                            "fragments": [
                                ":~:text=riddle,-yet%3F'"
                            ],
                            "progression": 0.43
                        ],
                        "text": [
                            "before": "'Have you guessed the ",
                            "highlight": "riddle",
                            "after": " yet?' the Hatter said, turning to Alice again."
                        ]
                    ],
                    [
                        "href": "/978-1503222687/chap7.html",
                        "type": "application/xhtml+xml",
                        "locations": [
                            "fragments": [
                                ":~:text=in%20asking-,riddles"
                            ],
                            "progression": 0.47
                        ],
                        "text": [
                            "before": "I'm glad they've begun asking ",
                            "highlight": "riddles",
                            "after": ".--I believe I can guess that,"
                        ]
                    ]
                ]
            ]),
            _LocatorCollection(
                metadata: _LocatorCollection.Metadata(
                    title: LocalizedString.localized([
                        "en": "Searching <riddle> in Alice in Wonderlands - Page 1",
                        "fr": "Recherche <riddle> dans Alice in Wonderlands – Page 1"
                    ]),
                    numberOfItems: 3,
                    otherMetadata: [
                        "extraMetadata": "value"
                    ]
                ),
                links: [
                    Link(href: "/978-1503222687/search?query=apple", type: "application/vnd.readium.locators+json", rel: "self"),
                    Link(href: "/978-1503222687/search?query=apple&page=2", type: "application/vnd.readium.locators+json", rel: "next")
                ],
                locators: [
                    Locator(
                        href: "/978-1503222687/chap7.html",
                        type: "application/xhtml+xml",
                        locations: Locator.Locations(
                            fragments: [":~:text=riddle,-yet%3F'"],
                            progression: 0.43
                        ),
                        text: Locator.Text(
                            after: " yet?' the Hatter said, turning to Alice again.",
                            before: "'Have you guessed the ",
                            highlight: "riddle"
                        )
                    ),
                    Locator(
                        href: "/978-1503222687/chap7.html",
                        type: "application/xhtml+xml",
                        locations: Locator.Locations(
                            fragments: [":~:text=in%20asking-,riddles"],
                            progression: 0.47
                        ),
                        text: Locator.Text(
                            after: ".--I believe I can guess that,",
                            before: "I'm glad they've begun asking ",
                            highlight: "riddles"
                        )
                    )
                ]
            )
        )
    }

    func testParseEmptyJSON() {
        XCTAssertEqual(
            _LocatorCollection(json: [:]),
            _LocatorCollection()
        )
    }

    func testParseNilJSON() {
        XCTAssertNil(_LocatorCollection(json: nil))
    }

    func testParseInvalidJSON() {
        XCTAssertNil(_LocatorCollection(json: []))
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            _LocatorCollection().json as Any,
            [
                "locators": []
            ]
        )
    }

    func testGetFullJSON() {
        AssertJSONEqual(
            _LocatorCollection(
                metadata: _LocatorCollection.Metadata(
                    title: LocalizedString.localized([
                        "en": "Searching <riddle> in Alice in Wonderlands - Page 1",
                        "fr": "Recherche <riddle> dans Alice in Wonderlands – Page 1"
                    ]),
                    numberOfItems: 3,
                    otherMetadata: [
                        "extraMetadata": "value"
                    ]
                ),
                links: [
                    Link(href: "/978-1503222687/search?query=apple", type: "application/vnd.readium.locators+json", rel: "self"),
                    Link(href: "/978-1503222687/search?query=apple&page=2", type: "application/vnd.readium.locators+json", rel: "next")
                ],
                locators: [
                    Locator(
                        href: "/978-1503222687/chap7.html",
                        type: "application/xhtml+xml",
                        locations: Locator.Locations(
                            fragments: [":~:text=riddle,-yet%3F'"],
                            progression: 0.43
                        ),
                        text: Locator.Text(
                            after: " yet?' the Hatter said, turning to Alice again.",
                            before: "'Have you guessed the ",
                            highlight: "riddle"
                        )
                    ),
                    Locator(
                        href: "/978-1503222687/chap7.html",
                        type: "application/xhtml+xml",
                        locations: Locator.Locations(
                            fragments: [":~:text=in%20asking-,riddles"],
                            progression: 0.47
                        ),
                        text: Locator.Text(
                            after: ".--I believe I can guess that,",
                            before: "I'm glad they've begun asking ",
                            highlight: "riddles"
                        )
                    )
                ]
            ).json as Any,
            [
                "metadata": [
                    "title": [
                        "en": "Searching <riddle> in Alice in Wonderlands - Page 1",
                        "fr": "Recherche <riddle> dans Alice in Wonderlands – Page 1"
                    ],
                    "numberOfItems": 3,
                    "extraMetadata": "value"
                ],
                "links": [
                    ["rel": ["self"], "href": "/978-1503222687/search?query=apple", "type": "application/vnd.readium.locators+json", "templated": false],
                    ["rel": ["next"], "href": "/978-1503222687/search?query=apple&page=2", "type": "application/vnd.readium.locators+json", "templated": false]
                ],
                "locators": [
                    [
                        "href": "/978-1503222687/chap7.html",
                        "type": "application/xhtml+xml",
                        "locations": [
                            "fragments": [
                                ":~:text=riddle,-yet%3F'"
                            ],
                            "progression": 0.43
                        ],
                        "text": [
                            "before": "'Have you guessed the ",
                            "highlight": "riddle",
                            "after": " yet?' the Hatter said, turning to Alice again."
                        ]
                    ],
                    [
                        "href": "/978-1503222687/chap7.html",
                        "type": "application/xhtml+xml",
                        "locations": [
                            "fragments": [
                                ":~:text=in%20asking-,riddles"
                            ],
                            "progression": 0.47
                        ],
                        "text": [
                            "before": "I'm glad they've begun asking ",
                            "highlight": "riddles",
                            "after": ".--I believe I can guess that,"
                        ]
                    ]
                ]
            ]
        )
    }
}
