//
//  PositionsServiceTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 30/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

struct TestPositionsService: PositionsService {
    
    let positionsByReadingOrder: [[Locator]]
    
    init(_ positions: [[Locator]]) {
        self.positionsByReadingOrder = positions
    }

}

class PositionsServiceTests: XCTestCase {
    
    let positions = [
        [
            Locator(
                href: "res",
                type: "application/xml",
                locations: .init(
                    totalProgression: 0.0,
                    position: 1
                )
            )
        ],
        [
            Locator(
                href: "chap1",
                type: "image/png",
                locations: .init(
                    totalProgression: 1.0 / 4.0,
                    position: 2
                )
            )
        ],
        [
            Locator(
                href: "chap2",
                type: "image/png",
                title: "Chapter 2",
                locations: .init(
                    totalProgression: 3.0 / 4.0,
                    position: 3
                )
            ),
            Locator(
                href: "chap2",
                type: "image/png",
                title: "Chapter 2.5",
                locations: .init(
                    totalProgression: 3.0 / 4.0,
                    position: 4
                )
            )
        ]
    ]
    
    func testLinks() {
        let service = TestPositionsService(positions)
        
        XCTAssertEqual(
            service.links,
            [Link(
                href: "/~readium/positions",
                type: "application/vnd.readium.position-list+json"
            )]
        )
    }
    
    func testPositions() {
        let service = TestPositionsService(positions)
        
        XCTAssertEqual(
            service.positions,
            [
                Locator(
                    href: "res",
                    type: "application/xml",
                    locations: .init(
                        totalProgression: 0.0,
                        position: 1
                    )
                ),
                Locator(
                    href: "chap1",
                    type: "image/png",
                    locations: .init(
                        totalProgression: 1.0 / 4.0,
                        position: 2
                    )
                ),
                Locator(
                    href: "chap2",
                    type: "image/png",
                    title: "Chapter 2",
                    locations: .init(
                        totalProgression: 3.0 / 4.0,
                        position: 3
                    )
                ),
                Locator(
                    href: "chap2",
                    type: "image/png",
                    title: "Chapter 2.5",
                    locations: .init(
                        totalProgression: 3.0 / 4.0,
                        position: 4
                    )
                )
            ]
        )
    }

    func testGetPositions() {
        let service = TestPositionsService(positions)
        
        let resource = service.get(link: Link(href: "/~readium/positions"))
        
        XCTAssertEqual(
            try resource?.readAsString().get(),
            """
            {"positions":[{"href":"res","locations":{"position":1,"totalProgression":0},"type":"application/xml"},{"href":"chap1","locations":{"position":2,"totalProgression":0.25},"type":"image/png"},{"href":"chap2","locations":{"position":3,"totalProgression":0.75},"title":"Chapter 2","type":"image/png"},{"href":"chap2","locations":{"position":4,"totalProgression":0.75},"title":"Chapter 2.5","type":"image/png"}],"total":4}
            """
        )
    }

    func testGetUnknown() {
        let service = TestPositionsService(positions)
        
        let resource = service.get(link: Link(href: "/unknown"))
        
        XCTAssertNil(resource)
    }
    
    /// The Publication helpers will use the `PositionsService` if there's one.
    func testPublicationHelpersUsesPositionsService() {
        let publication = makePublication(positions: { _ in TestPositionsService(self.positions) })

        XCTAssertEqual(publication.positionsByReadingOrder, positions)
        XCTAssertEqual(publication.positions, positions.flatMap { $0 })

        XCTAssertEqual(
            publication.positionsByResource,
            [
                "res": [
                    Locator(
                        href: "res",
                        type: "application/xml",
                        locations: .init(
                            totalProgression: 0.0,
                            position: 1
                        )
                    )
                ],
                "chap1": [
                    Locator(
                        href: "chap1",
                        type: "image/png",
                        locations: .init(
                            totalProgression: 1.0 / 4.0,
                            position: 2
                        )
                    )
                ],
                "chap2": [
                    Locator(
                        href: "chap2",
                        type: "image/png",
                        title: "Chapter 2",
                        locations: .init(
                            totalProgression: 3.0 / 4.0,
                            position: 3
                        )
                    ),
                    Locator(
                        href: "chap2",
                        type: "image/png",
                        title: "Chapter 2.5",
                        locations: .init(
                            totalProgression: 3.0 / 4.0,
                            position: 4
                        )
                    )
                ]

            ]
        )
    }
    
    /// The Publication helpers will attempt to fetch the positions from a Positions WS declared
    /// in the manifest if there is no service.
    func testPublicationHelpersFallbackOnManifest() {
        let publication = makePublication(positions: nil)
        
        XCTAssertEqual(publication.positions, [
            Locator(href: "chap1", type: "text/html", locations: .init(position: 1)),
            Locator(href: "chap1", type: "text/html", locations: .init(position: 2)),
            Locator(href: "chap2", type: "text/html", locations: .init(position: 3)),
        ])
        XCTAssertEqual(publication.positionsByReadingOrder, [
            [
                Locator(href: "chap1", type: "text/html", locations: .init(position: 1)),
                Locator(href: "chap1", type: "text/html", locations: .init(position: 2))
            ],
            [
                Locator(href: "chap2", type: "text/html", locations: .init(position: 3))
            ]
        ])
    }
    
    private func makePublication(positions: PositionsServiceFactory? = nil) -> Publication {
        // Serve a default positions WS from `/positions`.
        let positionsHref = "/positions"
        let fetcher = ProxyFetcher { link in
            guard link.href == "/positions" else {
                return FailureResource(link: link, error: .notFound)
            }
            
            return DataResource(link: link, string: """
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
                """)
        }
        
        return Publication(
            manifest: Manifest(
                metadata: Metadata(title: ""),
                links: [
                    Link(href: positionsHref, type: "application/vnd.readium.position-list+json")
                ],
                readingOrder: [
                    Link(href: "chap1", type: "text/html"),
                    Link(href: "chap2", type: "text/html")
                ]
            ),
            fetcher: fetcher,
            servicesBuilder: PublicationServicesBuilder(positions: positions)
        )
    }

}
