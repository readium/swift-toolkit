//
//  Copyright 2026 Readium Foundation. All rights reserved.
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
            ] as JSONValue),
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
        XCTAssertNil(try Locator(json: nil as JSONValue?))
    }

    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Locator(json: ""))
    }

    func testGetMinimalJSON() {
        XCTAssertEqual(
            Locator(
                href: "http://locator",
                mediaType: .html
            ).jsonObject,
            [
                "href": "http://locator",
                "type": "text/html",
            ]
        )
    }

    func testGetFullJSON() {
        XCTAssertEqual(
            Locator(
                href: "http://locator",
                mediaType: .html,
                title: "My Locator",
                locations: .init(position: 42),
                text: .init(highlight: "Excerpt")
            ).jsonObject,
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
            ] as [String: JSONValue]
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
        XCTAssertEqual(locator.jsonObject, locator.copy().jsonObject)

        let copy = locator.copy(
            title: "edited",
            locations: { $0.progression = 0.4 },
            text: { $0.before = "before" }
        )

        XCTAssertEqual(
            copy.jsonObject,
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
            ] as [String: JSONValue]
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
            ] as JSONValue),
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
            try Locator.Locations(json: [:] as JSONValue),
            Locator.Locations()
        )
    }

    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Locator.Locations(json: ""))
    }

    func testGetMinimalJSON() {
        XCTAssertEqual(
            Locator.Locations(
                position: 42
            ).jsonObject as [String: JSONValue],
            [
                "position": 42,
            ]
        )
    }

    func testGetFullJSON() {
        XCTAssertEqual(
            Locator.Locations(
                fragments: ["p=4", "frag34"],
                progression: 0.74,
                totalProgression: 25.32,
                position: 42,
                otherLocations: ["other": "other-location"]
            ).jsonObject as [String: JSONValue],
            [
                "fragments": ["p=4", "frag34"],
                "progression": 0.74,
                "totalProgression": 25.32,
                "position": 42,
                "other": "other-location",
            ] as [String: JSONValue]
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
            try Locator.Text(json: [:] as JSONValue),
            Locator.Text()
        )
    }

    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Locator.Text(json: ""))
    }

    func testGetMinimalJSON() {
        XCTAssertEqual(
            Locator.Text(
                after: "Text after"
            ).jsonObject as [String: JSONValue],
            [
                "after": "Text after",
            ]
        )
    }

    func testGetFullJSON() {
        XCTAssertEqual(
            Locator.Text(
                after: "Text after",
                before: "Text before",
                highlight: "Highlighted text"
            ).jsonObject as [String: JSONValue],
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

    func testSubstringFromRange() throws {
        let highlight = "highlight"
        let text = Locator.Text(
            after: "after",
            before: "before",
            highlight: highlight
        )

        XCTAssertEqual(
            try text[XCTUnwrap(highlight.range(of: "h"))],
            Locator.Text(
                after: "ighlightafter",
                before: "before",
                highlight: "h"
            )
        )

        XCTAssertEqual(
            try text[XCTUnwrap(highlight.range(of: "lig"))],
            Locator.Text(
                after: "htafter",
                before: "beforehigh",
                highlight: "lig"
            )
        )

        XCTAssertEqual(
            try text[XCTUnwrap(highlight.range(of: "highlight"))],
            Locator.Text(
                after: "after",
                before: "before",
                highlight: "highlight"
            )
        )

        XCTAssertEqual(
            try text[XCTUnwrap(highlight.range(of: "ght"))],
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

    func testSubstringFromARangeWithNilComponents() throws {
        let highlight = "highlight"

        XCTAssertEqual(
            try Locator.Text(
                after: nil,
                before: nil,
                highlight: highlight
            )[XCTUnwrap(highlight.range(of: "ghl"))],
            Locator.Text(
                after: "ight",
                before: "hi",
                highlight: "ghl"
            )
        )

        XCTAssertEqual(
            try Locator.Text(
                after: "after",
                before: nil,
                highlight: highlight
            )[XCTUnwrap(highlight.range(of: "hig"))],
            Locator.Text(
                after: "hlightafter",
                before: nil,
                highlight: "hig"
            )
        )

        XCTAssertEqual(
            try Locator.Text(
                after: nil,
                before: "before",
                highlight: highlight
            )[XCTUnwrap(highlight.range(of: "light"))],
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
            try LocatorCollection(json: [:] as JSONValue),
            LocatorCollection()
        )
    }

    func testParseFullJSON() throws {
        XCTAssertEqual(
            try LocatorCollection(json: [
                "metadata": [
                    "title": [
                        "en": "Searching <riddle> in Alice in Wonderlands - Page 1",
                        "fr": "Recherche <riddle> dans Alice in Wonderlands – Page 1",
                    ],
                    "numberOfItems": 3,
                    "extraMetadata": "value",
                ] as JSONValue,
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
                        ] as JSONValue,
                        "text": [
                            "before": "'Have you guessed the ",
                            "highlight": "riddle",
                            "after": " yet?' the Hatter said, turning to Alice again.",
                        ],
                    ] as JSONValue,
                    [
                        "href": "/978-1503222687/chap7.html",
                        "type": "application/xhtml+xml",
                        "locations": [
                            "fragments": [
                                ":~:text=in%20asking-,riddles",
                            ],
                            "progression": 0.47,
                        ] as JSONValue,
                        "text": [
                            "before": "I'm glad they've begun asking ",
                            "highlight": "riddles",
                            "after": ".--I believe I can guess that,",
                        ],
                    ],
                ],
            ] as JSONValue),
            try LocatorCollection(
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
                    Link(href: "/978-1503222687/search?query=apple", mediaType: XCTUnwrap(MediaType("application/vnd.readium.locators+json")), rel: "self"),
                    Link(href: "/978-1503222687/search?query=apple&page=2", mediaType: XCTUnwrap(MediaType("application/vnd.readium.locators+json")), rel: "next"),
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
            try LocatorCollection(json: [:] as JSONValue),
            LocatorCollection()
        )
    }

    func testParseNilJSON() {
        XCTAssertNil(try LocatorCollection(json: nil as JSONValue?))
    }

    func testParseInvalidJSON() {
        XCTAssertNil(try LocatorCollection(json: [] as JSONValue?))
    }

    func testGetMinimalJSON() {
        XCTAssertEqual(
            LocatorCollection().jsonObject as [String: JSONValue],
            [
                "locators": [] as JSONValue,
            ]
        )
    }

    func testGetFullJSON() throws {
        try XCTAssertEqual(
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
                    Link(href: "/978-1503222687/search?query=apple", mediaType: XCTUnwrap(MediaType("application/vnd.readium.locators+json")), rel: "self"),
                    Link(href: "/978-1503222687/search?query=apple&page=2", mediaType: XCTUnwrap(MediaType("application/vnd.readium.locators+json")), rel: "next"),
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
            ).jsonObject as [String: JSONValue],
            [
                "metadata": [
                    "title": [
                        "en": "Searching <riddle> in Alice in Wonderlands - Page 1",
                        "fr": "Recherche <riddle> dans Alice in Wonderlands – Page 1",
                    ],
                    "numberOfItems": 3,
                    "extraMetadata": "value",
                ] as JSONValue,
                "links": [
                    ["rel": ["self"], "href": "/978-1503222687/search?query=apple", "type": "application/vnd.readium.locators+json", "templated": false] as JSONValue,
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
                        ] as JSONValue,
                        "text": [
                            "before": "'Have you guessed the ",
                            "highlight": "riddle",
                            "after": " yet?' the Hatter said, turning to Alice again.",
                        ],
                    ] as JSONValue,
                    [
                        "href": "/978-1503222687/chap7.html",
                        "type": "application/xhtml+xml",
                        "locations": [
                            "fragments": [
                                ":~:text=in%20asking-,riddles",
                            ],
                            "progression": 0.47,
                        ] as JSONValue,
                        "text": [
                            "before": "I'm glad they've begun asking ",
                            "highlight": "riddles",
                            "after": ".--I believe I can guess that,",
                        ],
                    ],
                ],
            ] as [String: JSONValue]
        )
    }
}
