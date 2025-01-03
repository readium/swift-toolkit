//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

struct TestPositionsService: PositionsService {
    let positions: [[Locator]]

    init(_ positions: [[Locator]]) {
        self.positions = positions
    }

    func positionsByReadingOrder() async -> ReadResult<[[Locator]]> {
        .success(positions)
    }
}

class PositionsServiceTests: XCTestCase {
    let positions = [
        [
            Locator(
                href: "res",
                mediaType: .xml,
                locations: .init(
                    totalProgression: 0.0,
                    position: 1
                )
            ),
        ],
        [
            Locator(
                href: "chap1",
                mediaType: .png,
                locations: .init(
                    totalProgression: 1.0 / 4.0,
                    position: 2
                )
            ),
        ],
        [
            Locator(
                href: "chap2",
                mediaType: .png,
                title: "Chapter 2",
                locations: .init(
                    totalProgression: 3.0 / 4.0,
                    position: 3
                )
            ),
            Locator(
                href: "chap2",
                mediaType: .png,
                title: "Chapter 2.5",
                locations: .init(
                    totalProgression: 3.0 / 4.0,
                    position: 4
                )
            ),
        ],
    ]

    func testLinks() {
        let service = TestPositionsService(positions)

        XCTAssertEqual(
            service.links,
            [Link(
                href: "~readium/positions",
                mediaType: .readiumPositions
            )]
        )
    }

    func testPositions() async throws {
        let service = TestPositionsService(positions)

        let result = try await service.positions().get()
        XCTAssertEqual(
            result,
            [
                Locator(
                    href: "res",
                    mediaType: .xml,
                    locations: .init(
                        totalProgression: 0.0,
                        position: 1
                    )
                ),
                Locator(
                    href: "chap1",
                    mediaType: .png,
                    locations: .init(
                        totalProgression: 1.0 / 4.0,
                        position: 2
                    )
                ),
                Locator(
                    href: "chap2",
                    mediaType: .png,
                    title: "Chapter 2",
                    locations: .init(
                        totalProgression: 3.0 / 4.0,
                        position: 3
                    )
                ),
                Locator(
                    href: "chap2",
                    mediaType: .png,
                    title: "Chapter 2.5",
                    locations: .init(
                        totalProgression: 3.0 / 4.0,
                        position: 4
                    )
                ),
            ]
        )
    }

    func testGetPositions() async throws {
        let service = TestPositionsService(positions)

        let resource = service.get(AnyURL(string: "~readium/positions")!)

        let result = try await resource?.readAsString().get()
        XCTAssertEqual(
            result,
            """
            {"positions":[{"href":"res","locations":{"position":1,"totalProgression":0},"type":"application/xml"},{"href":"chap1","locations":{"position":2,"totalProgression":0.25},"type":"image/png"},{"href":"chap2","locations":{"position":3,"totalProgression":0.75},"title":"Chapter 2","type":"image/png"},{"href":"chap2","locations":{"position":4,"totalProgression":0.75},"title":"Chapter 2.5","type":"image/png"}],"total":4}
            """
        )
    }

    func testGetUnknown() {
        let service = TestPositionsService(positions)

        let resource = service.get(AnyURL(string: "/unknown")!)

        XCTAssertNil(resource)
    }

    /// The Publication helpers will use the `PositionsService` if there's one.
    func testPublicationHelpersUsesPositionsService() async throws {
        let publication = makePublication(positions: { _ in TestPositionsService(self.positions) })

        let resultPositionsByReadingOrder = try await publication.positionsByReadingOrder().get()
        XCTAssertEqual(resultPositionsByReadingOrder, positions)
        let resultPositions = try await publication.positions().get()
        XCTAssertEqual(resultPositions, positions.flatMap { $0 })
    }

    /// The Publication helpers will attempt to fetch the positions from a Positions WS declared
    /// in the manifest if there is no service.
    func testPublicationHelpersFallbackOnManifest() async throws {
        let publication = makePublication(positions: nil)

        let resultPositions = try await publication.positions().get()
        XCTAssertEqual(resultPositions, [
            Locator(href: "chap1", mediaType: .html, locations: .init(position: 1)),
            Locator(href: "chap1", mediaType: .html, locations: .init(position: 2)),
            Locator(href: "chap2", mediaType: .html, locations: .init(position: 3)),
        ])

        let resultPositionsByReadingOrder = try await publication.positionsByReadingOrder().get()
        XCTAssertEqual(resultPositionsByReadingOrder, [
            [
                Locator(href: "chap1", mediaType: .html, locations: .init(position: 1)),
                Locator(href: "chap1", mediaType: .html, locations: .init(position: 2)),
            ],
            [
                Locator(href: "chap2", mediaType: .html, locations: .init(position: 3)),
            ],
        ])
    }

    private func makePublication(positions: PositionsServiceFactory? = nil) -> Publication {
        // Serve a default positions WS from `positions`.
        let positionsHREF = AnyURL(string: "positions")!
        let container = SingleResourceContainer(
            resource: DataResource(string: """
            {
                "positions": [
                    {
                        "href": "chap1",
                        "locations": {
                            "position": 1
                        },
                        "type": "text/html"
                    },
                    {
                        "href": "chap1",
                        "locations": {
                            "position": 2
                        },
                        "type": "text/html"
                    },
                    {
                        "href": "chap2",
                        "locations": {
                            "position": 3
                        },
                        "type": "text/html"
                    }
                ],
                "total": 3
            }
            """),
            at: positionsHREF
        )

        return Publication(
            manifest: Manifest(
                metadata: Metadata(title: ""),
                links: [
                    Link(href: positionsHREF.string, mediaType: .readiumPositions),
                ],
                readingOrder: [
                    Link(href: "chap1", mediaType: .html),
                    Link(href: "chap2", mediaType: .html),
                ]
            ),
            container: container,
            servicesBuilder: PublicationServicesBuilder(positions: positions)
        )
    }
}
