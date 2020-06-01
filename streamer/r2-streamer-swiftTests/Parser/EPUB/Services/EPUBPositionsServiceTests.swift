//
//  EPUBPositionsServiceTests.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 01/06/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
import R2Shared
@testable import R2Streamer

class EPUBPositionsServiceTests: XCTestCase {

    func testFromEmptyReadingOrder() {
        let service = makeService(readingOrder: [])
        XCTAssertEqual(service.positionsByReadingOrder, [])
    }
    
    func testFromReadingOrderWithOneResource() {
        let service = makeService(readingOrder: [(1, Link(href: "res", type: "application/xml"))])
        
        XCTAssertEqual(service.positionsByReadingOrder, [[
            Locator(
                href: "res",
                type: "application/xml",
                locations: Locator.Locations(
                    progression: 0,
                    totalProgression: 0,
                    position: 1
                )
            )
        ]])
    }
    
    func testFromReadingOrderWithFewResources() {
        let service = makeService(readingOrder: [
            (1, Link(href: "res")),
            (2, Link(href: "chap1", type: "application/xml")),
            (2, Link(href: "chap2", type: "text/html", title: "Chapter 2"))
        ])

        XCTAssertEqual(service.positionsByReadingOrder, [
            [Locator(
                href: "res",
                type: "text/html",
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 0.0,
                    position: 1
                )
            )],
            [Locator(
                href: "chap1",
                type: "application/xml",
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 1.0/3.0,
                    position: 2
                )
            )],
            [Locator(
                href: "chap2",
                type: "text/html",
                title: "Chapter 2",
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 2.0/3.0,
                    position: 3
                )
            )]
        ])
    }
    
    func testTypeFallsBackOnHTML() {
        let service = makeService(readingOrder: [
            (1, Link(href: "chap1", properties: makeProperties(layout: .reflowable))),
            (1, Link(href: "chap2", properties: makeProperties(layout: .fixed)))
        ])

        XCTAssertEqual(service.positionsByReadingOrder, [
            [Locator(
                href: "chap1",
                type: "text/html",
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 0.0,
                    position: 1
                )
            )],
            [Locator(
                href: "chap2",
                type: "text/html",
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 0.5,
                    position: 2
                )
            )]
        ])
    }
    
    func testOnePositionPerFixedLayoutResource() {
        let service = makeService(
            layout: .fixed,
            readingOrder: [
                (10000, Link(href: "res")),
                (20000, Link(href: "chap1", type: "application/xml")),
                (40000, Link(href: "chap2", type: "text/html", title: "Chapter 2"))
            ]
        )

        XCTAssertEqual(service.positionsByReadingOrder, [
            [Locator(
                href: "res",
                type: "text/html",
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 0.0,
                    position: 1
                )
            )],
            [Locator(
                href: "chap1",
                type: "application/xml",
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 1.0/3.0,
                    position: 2
                )
            )],
            [Locator(
                href: "chap2",
                type: "text/html",
                title: "Chapter 2",
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 2.0/3.0,
                    position: 3
                )
            )]
        ])
    }
    
    func testSplitReflowableResourcesByProvidedLength() {
        let service = makeService(
            layout: .reflowable,
            readingOrder: [
                (0, Link(href: "chap1")),
                (49, Link(href: "chap2", type: "application/xml")),
                (50, Link(href: "chap3", type: "text/html", title: "Chapter 3")),
                (51, Link(href: "chap4")),
                (120, Link(href: "chap5"))
            ],
            reflowablePositionLength: 50
        )

        XCTAssertEqual(service.positionsByReadingOrder, [
            [
                Locator(
                    href: "chap1",
                    type: "text/html",
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 0.0,
                        position: 1
                    )
                )
            ],
            [
                Locator(
                    href: "chap2",
                    type: "application/xml",
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 1.0/8.0,
                        position: 2
                    )
                )
            ],
            [
                Locator(
                    href: "chap3",
                    type: "text/html",
                    title: "Chapter 3",
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 2.0/8.0,
                        position: 3
                    )
                )
            ],
            [
                Locator(
                    href: "chap4",
                    type: "text/html",
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 3.0/8.0,
                        position: 4
                    )
                ),
                Locator(
                    href: "chap4",
                    type: "text/html",
                    locations: Locator.Locations(
                        progression: 0.5,
                        totalProgression: 4.0/8.0,
                        position: 5
                    )
                )
            ],
            [
                Locator(
                    href: "chap5",
                    type: "text/html",
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 5.0/8.0,
                        position: 6
                    )
                ),
                Locator(
                    href: "chap5",
                    type: "text/html",
                    locations: Locator.Locations(
                        progression: 1.0/3.0,
                        totalProgression: 6.0/8.0,
                        position: 7
                    )
                ),
                Locator(
                    href: "chap5",
                    type: "text/html",
                    locations: Locator.Locations(
                        progression: 2.0/3.0,
                        totalProgression: 7.0/8.0,
                        position: 8
                    )
                )
            ]
        ])
    }
    
    func testLayoutFallsBackToReflowable() {
        // We check this by verifying that the resource will be split every 50 bytes
        let service = makeService(
            layout: nil,
            readingOrder: [
                (60, Link(href: "chap1"))
            ],
            reflowablePositionLength: 50
        )

        XCTAssertEqual(service.positionsByReadingOrder, [[
            Locator(
                href: "chap1",
                type: "text/html",
                locations: Locator.Locations(
                    progression: 0.0,
                    totalProgression: 0.0,
                    position: 1
                )
            ),
            Locator(
                href: "chap1",
                type: "text/html",
                locations: Locator.Locations(
                    progression: 0.5,
                    totalProgression: 0.5,
                    position: 2
                )
            )
        ]])
    }
    
    func testFromMixedLayouts() {
        let service = makeService(
            layout: .fixed,
            readingOrder: [
                (20000, Link(href: "chap1")),
                (60, Link(href: "chap2", properties: makeProperties(layout: .reflowable))),
                (20000, Link(href: "chap3", properties: makeProperties(layout: .fixed)))
            ],
            reflowablePositionLength: 50
        )

        XCTAssertEqual(service.positionsByReadingOrder, [
            [
                Locator(
                    href: "chap1",
                    type: "text/html",
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 0.0,
                        position: 1
                    )
                )
            ],
            [
                Locator(
                    href: "chap2",
                    type: "text/html",
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 1.0/4.0,
                        position: 2
                    )
                ),
                Locator(
                    href: "chap2",
                    type: "text/html",
                    locations: Locator.Locations(
                        progression: 0.5,
                        totalProgression: 2.0/4.0,
                        position: 3
                    )
                )
            ],
            [
                Locator(
                    href: "chap3",
                    type: "text/html",
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 3.0/4.0,
                        position: 4
                    )
                )
            ]
        ])
    }
    
    func testUsesOriginalLengthWhenAvailable() {
        let service = makeService(
            layout: .reflowable,
            readingOrder: [
                (60, Link(href: "chap1", properties: makeProperties(originalLength: 20))),
                (60, Link(href: "chap2"))
            ],
            reflowablePositionLength: 50
        )

        XCTAssertEqual(service.positionsByReadingOrder, [
            [
                Locator(
                    href: "chap1",
                    type: "text/html",
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 0.0,
                        position: 1
                    )
                )
            ],
            [
                Locator(
                    href: "chap2",
                    type: "text/html",
                    locations: Locator.Locations(
                        progression: 0.0,
                        totalProgression: 1.0/3.0,
                        position: 2
                    )
                ),
                Locator(
                    href: "chap2",
                    type: "text/html",
                    locations: Locator.Locations(
                        progression: 0.5,
                        totalProgression: 2.0/3.0,
                        position: 3
                    )
                )
            ]
        ])
    }

}

func makeService(layout: EPUBLayout? = nil, readingOrder: [(UInt64, Link)], reflowablePositionLength: Int = 50) -> EPUBPositionsService {
    return EPUBPositionsService(
        readingOrder: readingOrder.map { _, l in l },
        presentation: Presentation(layout: layout),
        fetcher: MockFetcher(readingOrder: readingOrder),
        reflowablePositionLength: reflowablePositionLength
    )
}

private func makeProperties(layout: EPUBLayout? = nil, originalLength: Int? = nil) -> Properties {
    var props: [String: Any] = [:]
    if let layout = layout {
        props["layout"] = layout.rawValue
    }
    if let originalLength = originalLength {
        props["encrypted"] = [
            "algorithm": "algo",
            "originalLength": originalLength
        ]
    }
    return Properties(props)
}

private class MockFetcher: Fetcher {
    
    private let readingOrder: [(UInt64, Link)]
    
    init(readingOrder: [(UInt64, Link)]) {
        self.readingOrder = readingOrder
    }
    
    var links: [Link] { [] }

    func get(_ requestedLink: Link) -> Resource {
        guard let (length, link) = readingOrder.first(where: { _, link in link.href == requestedLink.href }) else {
            return FailureResource(link: requestedLink, error: .notFound)
        }
        return MockResource(link: link, length: length)
    }
    
    func close() {}
    
    struct MockResource: Resource {

        let link: Link
        var length: ResourceResult<UInt64> { .success(_length) }
        
        private let _length: UInt64
        
        init(link: Link, length: UInt64) {
            self.link = link
            self._length = length
        }
        
        func read(range: Range<UInt64>?) -> ResourceResult<Data> { return .success(Data()) }
        func close() {}
    }

}
