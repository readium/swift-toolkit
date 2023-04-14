//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
import XCTest

class DefaultLocatorServiceTests: XCTestCase {
    // locate(Locator) checks that the href exists.
    func testFromLocator() {
        let service = makeService(readingOrder: [
            Link(href: "chap1", type: "application/xml"),
            Link(href: "chap2", type: "application/xml"),
            Link(href: "chap3", type: "application/xml"),
        ])
        let locator = Locator(href: "chap2", type: "text/html", text: .init(highlight: "Highlight"))
        XCTAssertEqual(service.locate(locator), locator)
    }

    func testFromLocatorEmptyReadingOrder() {
        let service = makeService(readingOrder: [])
        XCTAssertNil(service.locate(Locator(href: "href", type: "text/html")))
    }

    func testFromLocatorNotFound() {
        let service = makeService(readingOrder: [
            Link(href: "chap1", type: "application/xml"),
            Link(href: "chap3", type: "application/xml"),
        ])
        let locator = Locator(href: "chap2", type: "text/html", text: .init(highlight: "Highlight"))
        XCTAssertNil(service.locate(locator))
    }

    func testFromProgression() {
        let service = makeService(positions: positionsFixture)

        XCTAssertEqual(service.locate(progression: 0.0), Locator(
            href: "chap1",
            type: "text/html",
            locations: Locator.Locations(
                progression: 0.0,
                totalProgression: 0.0,
                position: 1
            )
        ))

        XCTAssertEqual(service.locate(progression: 0.25), Locator(
            href: "chap3",
            type: "text/html",
            title: "Chapter 3",
            locations: Locator.Locations(
                progression: 0.0,
                totalProgression: 2.0 / 8.0,
                position: 3
            )
        ))

        let chap5FirstTotalProg = 5.0 / 8.0
        let chap4FirstTotalProg = 3.0 / 8.0

        XCTAssertEqual(service.locate(progression: 0.4), Locator(
            href: "chap4",
            type: "text/html",
            locations: Locator.Locations(
                progression: (0.4 - chap4FirstTotalProg) / (chap5FirstTotalProg - chap4FirstTotalProg),
                totalProgression: 0.4,
                position: 4
            )
        ))

        XCTAssertEqual(service.locate(progression: 0.55), Locator(
            href: "chap4",
            type: "text/html",
            locations: Locator.Locations(
                progression: (0.55 - chap4FirstTotalProg) / (chap5FirstTotalProg - chap4FirstTotalProg),
                totalProgression: 0.55,
                position: 5
            )
        ))

        XCTAssertEqual(service.locate(progression: 0.9), Locator(
            href: "chap5",
            type: "text/html",
            locations: Locator.Locations(
                progression: (0.9 - chap5FirstTotalProg) / (1.0 - chap5FirstTotalProg),
                totalProgression: 0.9,
                position: 8
            )
        ))

        XCTAssertEqual(service.locate(progression: 1.0), Locator(
            href: "chap5",
            type: "text/html",
            locations: Locator.Locations(
                progression: 1.0,
                totalProgression: 1.0,
                position: 8
            )
        ))
    }

    func testFromIncorrectProgression() {
        let service = makeService(positions: positionsFixture)
        XCTAssertNil(service.locate(progression: -0.2))
        XCTAssertNil(service.locate(progression: 1.2))
    }

    func testFromProgressionEmptyPositions() {
        let service = makeService(positions: [])
        XCTAssertNil(service.locate(progression: 0.5))
    }

    func testFromMinimalLink() {
        let service = makeService(readingOrder: [
            Link(href: "/href", type: "text/html", title: "Resource"),
        ])

        XCTAssertEqual(
            service.locate(Link(href: "/href")),
            Locator(href: "/href", type: "text/html", title: "Resource", locations: Locator.Locations(progression: 0.0))
        )
    }

    func testFromLinkInReadingOrderResourcesOrLinks() {
        let service = makeService(
            links: [Link(href: "/href3", type: "text/html")],
            readingOrder: [Link(href: "/href1", type: "text/html")],
            resources: [Link(href: "/href2", type: "text/html")]
        )

        XCTAssertEqual(
            service.locate(Link(href: "/href1")),
            Locator(href: "/href1", type: "text/html", locations: Locator.Locations(progression: 0.0))
        )

        XCTAssertEqual(
            service.locate(Link(href: "/href2")),
            Locator(href: "/href2", type: "text/html", locations: Locator.Locations(progression: 0.0))
        )

        XCTAssertEqual(
            service.locate(Link(href: "/href3")),
            Locator(href: "/href3", type: "text/html", locations: Locator.Locations(progression: 0.0))
        )
    }

    func testFromLinkWithFragment() {
        let service = makeService(readingOrder: [
            Link(href: "/href", type: "text/html", title: "Resource"),
        ])

        XCTAssertEqual(
            service.locate(Link(href: "/href#page=42", type: "text/xml", title: "My link")),
            Locator(href: "/href", type: "text/html", title: "Resource", locations: Locator.Locations(fragments: ["page=42"]))
        )
    }

    func testTitleFallbackFromLink() {
        let service = makeService(readingOrder: [
            Link(href: "/href", type: "text/html"),
        ])

        XCTAssertEqual(
            service.locate(Link(href: "/href", title: "My link")),
            Locator(href: "/href", type: "text/html", title: "My link", locations: Locator.Locations(progression: 0.0))
        )
    }

    func testFromLinkNotFound() {
        let service = makeService(readingOrder: [
            Link(href: "/href", type: "text/html"),
        ])

        XCTAssertNil(service.locate(Link(href: "notfound")))
    }

    func makeService(
        links: [Link] = [],
        readingOrder: [Link] = [],
        resources: [Link] = [],
        positions: [[Locator]] = []
    ) -> DefaultLocatorService {
        DefaultLocatorService(publication: _Strong(Publication(
            manifest: Manifest(
                metadata: Metadata(title: ""),
                links: links,
                readingOrder: readingOrder,
                resources: resources
            ),
            servicesBuilder: PublicationServicesBuilder(
                positions: InMemoryPositionsService.makeFactory(positionsByReadingOrder: positions)
            )
        )))
    }
}

private let positionsFixture: [[Locator]] = [
    [
        Locator(
            href: "chap1",
            type: "text/html",
            locations: Locator.Locations(
                progression: 0.0,
                totalProgression: 0.0,
                position: 1
            )
        ),
    ],
    [
        Locator(
            href: "chap2",
            type: "application/xml",
            locations: Locator.Locations(
                progression: 0.0,
                totalProgression: 1.0 / 8.0,
                position: 2
            )
        ),
    ],
    [
        Locator(
            href: "chap3",
            type: "text/html",
            title: "Chapter 3",
            locations: Locator.Locations(
                progression: 0.0,
                totalProgression: 2.0 / 8.0,
                position: 3
            )
        ),
    ],
    [
        Locator(
            href: "chap4",
            type: "text/html",
            locations: Locator.Locations(
                progression: 0.0,
                totalProgression: 3.0 / 8.0,
                position: 4
            )
        ),
        Locator(
            href: "chap4",
            type: "text/html",
            locations: Locator.Locations(
                progression: 0.5,
                totalProgression: 4.0 / 8.0,
                position: 5
            )
        ),
    ],
    [
        Locator(
            href: "chap5",
            type: "text/html",
            locations: Locator.Locations(
                progression: 0.0,
                totalProgression: 5.0 / 8.0,
                position: 6
            )
        ),
        Locator(
            href: "chap5",
            type: "text/html",
            locations: Locator.Locations(
                progression: 1.0 / 3.0,
                totalProgression: 6.0 / 8.0,
                position: 7
            )
        ),
        Locator(
            href: "chap5",
            type: "text/html",
            locations: Locator.Locations(
                progression: 2.0 / 3.0,
                totalProgression: 7.0 / 8.0,
                position: 8
            )
        ),
    ],
]
