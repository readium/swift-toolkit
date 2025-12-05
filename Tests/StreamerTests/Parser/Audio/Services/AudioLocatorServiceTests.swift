//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
@testable import ReadiumStreamer
import XCTest

class AudioLocatorServiceTests: XCTestCase {
    func testLocateLocatorMatchingReadingOrderHREF() async {
        let service = makeService(readingOrder: [
            Link(href: "l1"),
            Link(href: "l2"),
        ])

        let locator = Locator(href: "l1", mediaType: .mp3, locations: .init(totalProgression: 0.53))
        let result = await service.locate(locator)
        XCTAssertEqual(result, locator)
    }

    func testLocateLocatorReturnsNilIfNoMatch() async {
        let service = makeService(readingOrder: [
            Link(href: "l1"),
            Link(href: "l2"),
        ])

        let locator = Locator(href: "l3", mediaType: .mp3, locations: .init(totalProgression: 0.53))
        let result = await service.locate(locator)
        XCTAssertNil(result)
    }

    func testLocateLocatorUsesTotalProgression() async {
        let service = makeService(readingOrder: [
            Link(href: "l1", mediaType: .mp3, duration: 100),
            Link(href: "l2", mediaType: .mp3, duration: 100),
        ])

        var result = await service.locate(Locator(href: "wrong", mediaType: .mp3, locations: .init(totalProgression: 0.49)))
        XCTAssertEqual(
            result,
            Locator(href: "l1", mediaType: .mp3, locations: .init(
                fragments: ["t=98"],
                progression: 98 / 100.0,
                totalProgression: 0.49
            ))
        )

        result = await service.locate(Locator(href: "wrong", mediaType: .mp3, locations: .init(totalProgression: 0.5)))
        XCTAssertEqual(
            result,
            Locator(href: "l2", mediaType: .mp3, locations: .init(
                fragments: ["t=0"],
                progression: 0,
                totalProgression: 0.5
            ))
        )

        result = await service.locate(Locator(href: "wrong", mediaType: .mp3, locations: .init(totalProgression: 0.51)))
        XCTAssertEqual(
            result,
            Locator(href: "l2", mediaType: .mp3, locations: .init(
                fragments: ["t=2"],
                progression: 0.02,
                totalProgression: 0.51
            ))
        )
    }

    func testLocateLocatorUsingTotalProgressionKeepsTitleAndText() async {
        let service = makeService(readingOrder: [
            Link(href: "l1", mediaType: .mp3, duration: 100),
            Link(href: "l2", mediaType: .mp3, duration: 100),
        ])

        let result = await service.locate(
            Locator(
                href: "wrong",
                mediaType: MediaType("text/plain")!,
                title: "Title",
                locations: .init(
                    fragments: ["ignored"],
                    progression: 0.5,
                    totalProgression: 0.4,
                    position: 42,
                    otherLocations: ["other": "location"]
                ),
                text: .init(after: "after", before: "before", highlight: "highlight")
            )
        )

        XCTAssertEqual(
            result,
            Locator(
                href: "l1",
                mediaType: .mp3,
                title: "Title",
                locations: .init(
                    fragments: ["t=80"],
                    progression: 80 / 100.0,
                    totalProgression: 0.4
                ),
                text: .init(after: "after", before: "before", highlight: "highlight")
            )
        )
    }

    func testLocateProgression() async {
        let service = makeService(readingOrder: [
            Link(href: "l1", mediaType: .mp3, duration: 100),
            Link(href: "l2", mediaType: .mp3, duration: 100),
        ])

        var result = await service.locate(progression: 0)
        XCTAssertEqual(
            result,
            Locator(href: "l1", mediaType: .mp3, locations: .init(
                fragments: ["t=0"],
                progression: 0,
                totalProgression: 0
            ))
        )

        result = await service.locate(progression: 0.49)
        XCTAssertEqual(
            result,
            Locator(href: "l1", mediaType: .mp3, locations: .init(
                fragments: ["t=98"],
                progression: 98 / 100.0,
                totalProgression: 0.49
            ))
        )

        result = await service.locate(progression: 0.5)
        XCTAssertEqual(
            result,
            Locator(href: "l2", mediaType: .mp3, locations: .init(
                fragments: ["t=0"],
                progression: 0,
                totalProgression: 0.5
            ))
        )

        result = await service.locate(progression: 0.51)
        XCTAssertEqual(
            result,
            Locator(href: "l2", mediaType: .mp3, locations: .init(
                fragments: ["t=2"],
                progression: 0.02,
                totalProgression: 0.51
            ))
        )

        result = await service.locate(progression: 1)
        XCTAssertEqual(
            result,
            Locator(href: "l2", mediaType: .mp3, locations: .init(
                fragments: ["t=100"],
                progression: 1,
                totalProgression: 1
            ))
        )
    }

    func testLocateInvalidProgression() async {
        let service = makeService(readingOrder: [
            Link(href: "l1", mediaType: .mp3, duration: 100),
            Link(href: "l2", mediaType: .mp3, duration: 100),
        ])

        var result = await service.locate(progression: -0.5)
        XCTAssertNil(result)

        result = await service.locate(progression: 1.5)
        XCTAssertNil(result)
    }

    private func makeService(readingOrder: [Link]) -> AudioLocatorService {
        AudioLocatorService(
            publication: _Strong(Publication(
                manifest: Manifest(metadata: Metadata(title: ""), readingOrder: readingOrder)
            ))
        )
    }
}
