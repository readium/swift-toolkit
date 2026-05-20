//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class DefaultLocatorServiceTests: XCTestCase {
    /// locate(Locator) checks that the href exists.
    func testFromLocator() async {
        let (publication, service) = makeService(readingOrder: [
            Link(href: "chap1", mediaType: .xml),
            Link(href: "chap2", mediaType: .xml),
            Link(href: "chap3", mediaType: .xml),
        ])
        _ = publication // Silence warning
        let locator = Locator(href: "chap2", mediaType: .html, text: .init(highlight: "Highlight"))
        let result = await service.locate(locator)
        XCTAssertEqual(result, locator)
    }

    func testFromLocatorEmptyReadingOrder() async {
        let (publication, service) = makeService(readingOrder: [])
        _ = publication // Silence warning
        let result = await service.locate(Locator(href: "href", mediaType: .html))
        XCTAssertNil(result)
    }

    func testFromLocatorNotFound() async {
        let (publication, service) = makeService(readingOrder: [
            Link(href: "chap1", mediaType: .xml),
            Link(href: "chap3", mediaType: .xml),
        ])
        _ = publication // Silence warning
        let locator = Locator(href: "chap2", mediaType: .html, text: .init(highlight: "Highlight"))
        let result = await service.locate(locator)
        XCTAssertNil(result)
    }

    func testFromProgression() async {
        let (publication, service) = makeService(positions: positionsFixture)
        _ = publication // Silence warning

        var result = await service.locate(progression: 0.0)
        XCTAssertEqual(result, Locator(
            href: "chap1",
            mediaType: .html,
            locations: Locator.Locations(
                progression: 0.0,
                totalProgression: 0.0,
                position: 1
            )
        ))

        result = await service.locate(progression: 0.25)
        XCTAssertEqual(result, Locator(
            href: "chap3",
            mediaType: .html,
            title: "Chapter 3",
            locations: Locator.Locations(
                progression: 0.0,
                totalProgression: 2.0 / 8.0,
                position: 3
            )
        ))

        let chap5FirstTotalProg = 5.0 / 8.0
        let chap4FirstTotalProg = 3.0 / 8.0

        result = await service.locate(progression: 0.4)
        XCTAssertEqual(result, Locator(
            href: "chap4",
            mediaType: .html,
            locations: Locator.Locations(
                progression: (0.4 - chap4FirstTotalProg) / (chap5FirstTotalProg - chap4FirstTotalProg),
                totalProgression: 0.4,
                position: 4
            )
        ))

        result = await service.locate(progression: 0.55)
        XCTAssertEqual(result, Locator(
            href: "chap4",
            mediaType: .html,
            locations: Locator.Locations(
                progression: (0.55 - chap4FirstTotalProg) / (chap5FirstTotalProg - chap4FirstTotalProg),
                totalProgression: 0.55,
                position: 5
            )
        ))

        result = await service.locate(progression: 0.9)
        XCTAssertEqual(result, Locator(
            href: "chap5",
            mediaType: .html,
            locations: Locator.Locations(
                progression: (0.9 - chap5FirstTotalProg) / (1.0 - chap5FirstTotalProg),
                totalProgression: 0.9,
                position: 8
            )
        ))

        result = await service.locate(progression: 1.0)
        XCTAssertEqual(result, Locator(
            href: "chap5",
            mediaType: .html,
            locations: Locator.Locations(
                progression: 1.0,
                totalProgression: 1.0,
                position: 8
            )
        ))
    }

    func testFromIncorrectProgression() async {
        let (publication, service) = makeService(positions: positionsFixture)
        _ = publication // Silence warning

        var result = await service.locate(progression: -0.2)
        XCTAssertNil(result)

        result = await service.locate(progression: 1.2)
        XCTAssertNil(result)
    }

    func testFromProgressionEmptyPositions() async {
        let (publication, service) = makeService(positions: [])
        _ = publication // Silence warning
        let result = await service.locate(progression: 0.5)
        XCTAssertNil(result)
    }

    func testFromMinimalLink() async {
        let (publication, service) = makeService(readingOrder: [
            Link(href: "/href", mediaType: .html, title: "Resource"),
        ])
        _ = publication // Silence warning

        let result = await service.locate(Link(href: "/href"))
        XCTAssertEqual(
            result,
            Locator(href: "/href", mediaType: .html, title: "Resource", locations: Locator.Locations(progression: 0.0))
        )
    }

    func testFromLinkInReadingOrderResourcesOrLinks() async {
        let (publication, service) = makeService(
            links: [Link(href: "/href3", mediaType: .html)],
            readingOrder: [Link(href: "/href1", mediaType: .html)],
            resources: [Link(href: "/href2", mediaType: .html)]
        )
        _ = publication // Silence warning

        var result = await service.locate(Link(href: "/href1"))
        XCTAssertEqual(
            result,
            Locator(href: "/href1", mediaType: .html, locations: Locator.Locations(progression: 0.0))
        )

        result = await service.locate(Link(href: "/href2"))
        XCTAssertEqual(
            result,
            Locator(href: "/href2", mediaType: .html, locations: Locator.Locations(progression: 0.0))
        )

        result = await service.locate(Link(href: "/href3"))
        XCTAssertEqual(
            result,
            Locator(href: "/href3", mediaType: .html, locations: Locator.Locations(progression: 0.0))
        )
    }

    func testFromLinkWithFragment() async throws {
        let (publication, service) = makeService(readingOrder: [
            Link(href: "/href", mediaType: .html, title: "Resource"),
        ])
        _ = publication // Silence warning

        let result = try await service.locate(Link(href: "/href#page=42", mediaType: XCTUnwrap(MediaType("text/xml")), title: "My link"))
        XCTAssertEqual(
            result,
            Locator(href: "/href", mediaType: .html, title: "Resource", locations: Locator.Locations(fragments: ["page=42"]))
        )
    }

    func testTitleFallbackFromLink() async {
        let (publication, service) = makeService(readingOrder: [
            Link(href: "/href", mediaType: .html),
        ])
        _ = publication // Silence warning

        let result = await service.locate(Link(href: "/href", title: "My link"))
        XCTAssertEqual(
            result,
            Locator(href: "/href", mediaType: .html, title: "My link", locations: Locator.Locations(progression: 0.0))
        )
    }

    func testFromLinkNotFound() async {
        let (publication, service) = makeService(readingOrder: [
            Link(href: "/href", mediaType: .html),
        ])
        _ = publication // Silence warning

        let result = await service.locate(Link(href: "notfound"))
        XCTAssertNil(result)
    }

    func makeService(
        links: [Link] = [],
        readingOrder: [Link] = [],
        resources: [Link] = [],
        positions: [[Locator]] = []
    ) -> (Publication, DefaultLocatorService) {
        let publication = Publication(
            manifest: Manifest(
                metadata: Metadata(title: ""),
                links: links,
                readingOrder: readingOrder,
                resources: resources
            ),
            servicesBuilder: PublicationServicesBuilder(
                positions: InMemoryPositionsService.makeFactory(positionsByReadingOrder: positions)
            )
        )
        let service = DefaultLocatorService(publication: Weak(publication))
        return (publication, service)
    }
}

private let positionsFixture: [[Locator]] = [
    [
        Locator(
            href: "chap1",
            mediaType: .html,
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
            mediaType: .xml,
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
            mediaType: .html,
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
            mediaType: .html,
            locations: Locator.Locations(
                progression: 0.0,
                totalProgression: 3.0 / 8.0,
                position: 4
            )
        ),
        Locator(
            href: "chap4",
            mediaType: .html,
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
            mediaType: .html,
            locations: Locator.Locations(
                progression: 0.0,
                totalProgression: 5.0 / 8.0,
                position: 6
            )
        ),
        Locator(
            href: "chap5",
            mediaType: .html,
            locations: Locator.Locations(
                progression: 1.0 / 3.0,
                totalProgression: 6.0 / 8.0,
                position: 7
            )
        ),
        Locator(
            href: "chap5",
            mediaType: .html,
            locations: Locator.Locations(
                progression: 2.0 / 3.0,
                totalProgression: 7.0 / 8.0,
                position: 8
            )
        ),
    ],
]
