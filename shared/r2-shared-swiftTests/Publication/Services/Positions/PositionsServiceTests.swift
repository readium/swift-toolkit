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
    
    func testPublicationHelpers() {
        let service = TestPositionsService(positions)
        var builder = PublicationServicesBuilder()
        builder.set(PositionsService.self) { _ in TestPositionsService(self.positions) }
        
        let publication = Publication(
            manifest: .init(metadata: .init(title: "")),
            servicesBuilder: builder
        )
        
        XCTAssertEqual(publication.positions, service.positions)
        XCTAssertEqual(publication.positionsByReadingOrder, service.positionsByReadingOrder)
        
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
    
    func testPublicationHelpersWithoutService() {
        let publication = Publication(
            manifest: .init(metadata: .init(title: ""))
        )
        
        XCTAssertEqual(publication.positions, [])
        XCTAssertEqual(publication.positionsByReadingOrder, [])
    }

}
