//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class LocatorTests: XCTestCase {
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Locator(json: [
                "href": "http://locator",
                "type": "text/html",
            ]),
            Locator(
                href: "http://locator",
                mediaType: .html
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
                    "position": 42,
                ],
                "text": [
                    "highlight": "Excerpt",
                ],
            ] as [String: Any]),
            Locator(
                href: "http://locator",
                mediaType: .html,
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
                Locator(href: "loc1", mediaType: .html),
                Locator(href: "loc2", mediaType: .html),
            ]
        )
    }

    func testParseJSONArrayWhenNil() {
        XCTAssertEqual([Locator](json: nil), [])
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            Locator(
                href: "http://locator",
                mediaType: .html
            ).json,
            [
                "href": "http://locator",
                "type": "text/html",
            ]
        )
    }

    func testGetFullJSON() {
        AssertJSONEqual(
            Locator(
                href: "http://locator",
                mediaType: .html,
                title: "My Locator",
                locations: .init(position: 42),
                text: .init(highlight: "Excerpt")
            ).json,
            [
                "href": "http://locator",
                "type": "text/html",
                "title": "My Locator",
                "locations": [
                    "position": 42,
                ],
                "text": [
                    "highlight": "Excerpt",
                ],
            ] as [String: Any]
        )
    }

    func testGetJSONArray() {
        AssertJSONEqual(
            [
                Locator(href: "loc1", mediaType: .html),
                Locator(href: "loc2", mediaType: .html),
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
            mediaType: .html,
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
                    "progression": 0.4,
                ],
                "text": [
                    "before": "before",
                    "highlight": "Excerpt",
                ],
            ] as [String: Any]
        )
    }
}

class LocatorLocationsTests: XCTestCase {
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Locator.Locations(json: [
                "position": 42,
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
                "other": "other-location",
            ] as [String: Any]),
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
            try Locator.Locations(json: [:] as [String: Any]),
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
                "position": 42,
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
                "other": "other-location",
            ] as [String: Any]
        )
    }
}

class LocatorTextTests: XCTestCase {
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Locator.Text(json: [
                "after": "Text after",
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
                "highlight": "Highlighted text",
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
            try Locator.Text(json: [:] as [String: Any]),
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
                "after": "Text after",
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
                "highlight": "Highlighted text",
            ]
        )
    }

    func testGetSanitizedText() {
        XCTAssertEqual(
            Locator.Text(
                after: "\t\n\n  after \n\t  selection  \n\t",
                before: "\t\n\n  before \n\t  selection  \n\t",
                highlight: "\t\n\n  current \n\t  selection  \n\t"
            ).sanitized(),
            Locator.Text(
                after: " after selection",
                before: "before selection ",
                highlight: " current selection "
            )
        )
        XCTAssertEqual(
            Locator.Text(
                after: "after selection",
                before: "before selection",
                highlight: " current selection "
            ).sanitized(),
            Locator.Text(
                after: "after selection",
                before: "before selection",
                highlight: " current selection "
            )
        )
        XCTAssertEqual(
            Locator.Text(
                after: " after selection",
                before: "before selection ",
                highlight: "current selection"
            ).sanitized(),
            Locator.Text(
                after: " after selection",
                before: "before selection ",
                highlight: "current selection"
            )
        )
    }

    func testSubstringFromRange() {
        let highlight = "highlight"
        let text = Locator.Text(
            after: "after",
            before: "before",
            highlight: highlight
        )

        XCTAssertEqual(
            text[highlight.range(of: "h")!],
            Locator.Text(
                after: "ighlightafter",
                before: "before",
                highlight: "h"
            )
        )

        XCTAssertEqual(
            text[highlight.range(of: "lig")!],
            Locator.Text(
                after: "htafter",
                before: "beforehigh",
                highlight: "lig"
            )
        )

        XCTAssertEqual(
            text[highlight.range(of: "highlight")!],
            Locator.Text(
                after: "after",
                before: "before",
                highlight: "highlight"
            )
        )

        XCTAssertEqual(
            text[highlight.range(of: "ght")!],
            Locator.Text(
                after: "after",
                before: "beforehighli",
                highlight: "ght"
            )
        )

        let longer = "Longer than highlight"

        XCTAssertEqual(
            text[longer.index(longer.startIndex, offsetBy: 8) ..< longer.index(longer.startIndex, offsetBy: 13)],
            Locator.Text(
                after: "after",
                before: "beforehighligh",
                highlight: "t"
            )
        )

        XCTAssertEqual(
            text[longer.index(longer.startIndex, offsetBy: 9) ..< longer.index(longer.startIndex, offsetBy: 13)],
            Locator.Text(
                after: "after",
                before: "beforehighlight",
                highlight: ""
            )
        )
    }

    func testSubstringFromARangeWithNilComponents() {
        let highlight = "highlight"

        XCTAssertEqual(
            Locator.Text(
                after: nil,
                before: nil,
                highlight: highlight
            )[highlight.range(of: "ghl")!],
            Locator.Text(
                after: "ight",
                before: "hi",
                highlight: "ghl"
            )
        )

        XCTAssertEqual(
            Locator.Text(
                after: "after",
                before: nil,
                highlight: highlight
            )[highlight.range(of: "hig")!],
            Locator.Text(
                after: "hlightafter",
                before: nil,
                highlight: "hig"
            )
        )

        XCTAssertEqual(
            Locator.Text(
                after: nil,
                before: "before",
                highlight: highlight
            )[highlight.range(of: "light")!],
            Locator.Text(
                after: nil,
                before: "beforehigh",
                highlight: "light"
            )
        )
    }
}

class LocatorCollectionTests: XCTestCase {
    func testParseMinimalJSON() {
        XCTAssertEqual(
            LocatorCollection(json: [:] as [String: Any]),
            LocatorCollection()
        )
    }

    func testParseFullJSON() {
        XCTAssertEqual(
            LocatorCollection(json: [
                "metadata": [
                    "title": [
                        "en": "Searching <riddle> in Alice in Wonderlands - Page 1",
                        "fr": "Recherche <riddle> dans Alice in Wonderlands – Page 1",
                    ],
                    "numberOfItems": 3,
                    "extraMetadata": "value",
                ] as [String: Any],
                "links": [
                    ["rel": "self", "href": "/978-1503222687/search?query=apple", "type": "application/vnd.readium.locators+json"],
                    ["rel": "next", "href": "/978-1503222687/search?query=apple&page=2", "type": "application/vnd.readium.locators+json"],
                ],
                "locators": [
                    [
                        "href": "/978-1503222687/chap7.html",
                        "type": "application/xhtml+xml",
                        "locations": [
                            "fragments": [
                                ":~:text=riddle,-yet%3F'",
                            ],
                            "progression": 0.43,
                        ] as [String: Any],
                        "text": [
                            "before": "'Have you guessed the ",
                            "highlight": "riddle",
                            "after": " yet?' the Hatter said, turning to Alice again.",
                        ],
                    ] as [String: Any],
                    [
                        "href": "/978-1503222687/chap7.html",
                        "type": "application/xhtml+xml",
                        "locations": [
                            "fragments": [
                                ":~:text=in%20asking-,riddles",
                            ],
                            "progression": 0.47,
                        ] as [String: Any],
                        "text": [
                            "before": "I'm glad they've begun asking ",
                            "highlight": "riddles",
                            "after": ".--I believe I can guess that,",
                        ],
                    ],
                ],
            ] as [String: Any]),
            LocatorCollection(
                metadata: LocatorCollection.Metadata(
                    title: LocalizedString.localized([
                        "en": "Searching <riddle> in Alice in Wonderlands - Page 1",
                        "fr": "Recherche <riddle> dans Alice in Wonderlands – Page 1",
                    ]),
                    numberOfItems: 3,
                    otherMetadata: [
                        "extraMetadata": "value",
                    ]
                ),
                links: [
                    Link(href: "/978-1503222687/search?query=apple", mediaType: MediaType("application/vnd.readium.locators+json")!, rel: "self"),
                    Link(href: "/978-1503222687/search?query=apple&page=2", mediaType: MediaType("application/vnd.readium.locators+json")!, rel: "next"),
                ],
                locators: [
                    Locator(
                        href: "/978-1503222687/chap7.html",
                        mediaType: .xhtml,
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
                        mediaType: .xhtml,
                        locations: Locator.Locations(
                            fragments: [":~:text=in%20asking-,riddles"],
                            progression: 0.47
                        ),
                        text: Locator.Text(
                            after: ".--I believe I can guess that,",
                            before: "I'm glad they've begun asking ",
                            highlight: "riddles"
                        )
                    ),
                ]
            )
        )
    }

    func testParseEmptyJSON() {
        XCTAssertEqual(
            LocatorCollection(json: [:] as [String: Any]),
            LocatorCollection()
        )
    }

    func testParseNilJSON() {
        XCTAssertNil(LocatorCollection(json: nil))
    }

    func testParseInvalidJSON() {
        XCTAssertNil(LocatorCollection(json: [] as [Any]))
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            LocatorCollection().json as Any,
            [
                "locators": [] as [Any],
            ]
        )
    }

    func testGetFullJSON() {
        AssertJSONEqual(
            LocatorCollection(
                metadata: LocatorCollection.Metadata(
                    title: LocalizedString.localized([
                        "en": "Searching <riddle> in Alice in Wonderlands - Page 1",
                        "fr": "Recherche <riddle> dans Alice in Wonderlands – Page 1",
                    ]),
                    numberOfItems: 3,
                    otherMetadata: [
                        "extraMetadata": "value",
                    ]
                ),
                links: [
                    Link(href: "/978-1503222687/search?query=apple", mediaType: MediaType("application/vnd.readium.locators+json")!, rel: "self"),
                    Link(href: "/978-1503222687/search?query=apple&page=2", mediaType: MediaType("application/vnd.readium.locators+json")!, rel: "next"),
                ],
                locators: [
                    Locator(
                        href: "/978-1503222687/chap7.html",
                        mediaType: .xhtml,
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
                        mediaType: .xhtml,
                        locations: Locator.Locations(
                            fragments: [":~:text=in%20asking-,riddles"],
                            progression: 0.47
                        ),
                        text: Locator.Text(
                            after: ".--I believe I can guess that,",
                            before: "I'm glad they've begun asking ",
                            highlight: "riddles"
                        )
                    ),
                ]
            ).json as Any,
            [
                "metadata": [
                    "title": [
                        "en": "Searching <riddle> in Alice in Wonderlands - Page 1",
                        "fr": "Recherche <riddle> dans Alice in Wonderlands – Page 1",
                    ],
                    "numberOfItems": 3,
                    "extraMetadata": "value",
                ] as [String: Any],
                "links": [
                    ["rel": ["self"], "href": "/978-1503222687/search?query=apple", "type": "application/vnd.readium.locators+json", "templated": false] as [String: Any],
                    ["rel": ["next"], "href": "/978-1503222687/search?query=apple&page=2", "type": "application/vnd.readium.locators+json", "templated": false],
                ],
                "locators": [
                    [
                        "href": "/978-1503222687/chap7.html",
                        "type": "application/xhtml+xml",
                        "locations": [
                            "fragments": [
                                ":~:text=riddle,-yet%3F'",
                            ],
                            "progression": 0.43,
                        ] as [String: Any],
                        "text": [
                            "before": "'Have you guessed the ",
                            "highlight": "riddle",
                            "after": " yet?' the Hatter said, turning to Alice again.",
                        ],
                    ] as [String: Any],
                    [
                        "href": "/978-1503222687/chap7.html",
                        "type": "application/xhtml+xml",
                        "locations": [
                            "fragments": [
                                ":~:text=in%20asking-,riddles",
                            ],
                            "progression": 0.47,
                        ] as [String: Any],
                        "text": [
                            "before": "I'm glad they've begun asking ",
                            "highlight": "riddles",
                            "after": ".--I believe I can guess that,",
                        ],
                    ],
                ],
            ] as [String: Any]
        )
    }
}
