//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
import XCTest

class PerResourcePositionsServiceTests: XCTestCase {
    func testFromAnEmptyReadingOrder() {
        let service = PerResourcePositionsService(readingOrder: [], fallbackMediaType: "")
        XCTAssertEqual(service.positionsByReadingOrder, [])
    }

    func testFromReadingOrderWithOneResource() {
        let service = PerResourcePositionsService(readingOrder: [
            Link(href: "res", type: "image/png"),
        ], fallbackMediaType: "")

        XCTAssertEqual(service.positionsByReadingOrder, [
            [Locator(
                href: "res",
                type: "image/png",
                locations: Locator.Locations(
                    totalProgression: 0.0,
                    position: 1
                )
            )],
        ])
    }

    func testFromReadingOrderWithFewResources() {
        let service = PerResourcePositionsService(
            readingOrder: [
                Link(href: "res"),
                Link(href: "chap1", type: "image/png"),
                Link(href: "chap2", type: "image/png", title: "Chapter 2"),
            ],
            fallbackMediaType: ""
        )

        XCTAssertEqual(service.positionsByReadingOrder, [
            [Locator(
                href: "res",
                type: "",
                locations: Locator.Locations(
                    totalProgression: 0.0,
                    position: 1
                )
            )],
            [Locator(
                href: "chap1",
                type: "image/png",
                locations: Locator.Locations(
                    totalProgression: 1.0 / 3.0,
                    position: 2
                )
            )],
            [Locator(
                href: "chap2",
                type: "image/png",
                title: "Chapter 2",
                locations: Locator.Locations(
                    totalProgression: 2.0 / 3.0,
                    position: 3
                )
            )],
        ])
    }

    func testFallsBackOnGivenMediaType() {
        let services = PerResourcePositionsService(
            readingOrder: [Link(href: "res")],
            fallbackMediaType: "image/*"
        )

        XCTAssertEqual(services.positionsByReadingOrder, [[
            Locator(
                href: "res",
                type: "image/*",
                locations: Locator.Locations(
                    totalProgression: 0.0,
                    position: 1
                )
            ),
        ]])
    }
}
