//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import XCTest
import R2Shared
@testable import R2Streamer

class AudioLocatorServiceTests: XCTestCase {

    func testLocateLocatorMatchingReadingOrderHREF() {
        let service = makeService(readingOrder: [
            Link(href: "l1"),
            Link(href: "l2")
        ])
        
        let locator = Locator(href: "l1", type: "audio/mpeg", locations: .init(totalProgression: 0.53))
        XCTAssertEqual(service.locate(locator), locator)
    }
    
    func testLocateLocatorReturnsNilIfNoMatch() {
        let service = makeService(readingOrder: [
            Link(href: "l1"),
            Link(href: "l2")
        ])
        
        let locator = Locator(href: "l3", type: "audio/mpeg", locations: .init(totalProgression: 0.53))
        XCTAssertNil(service.locate(locator))
    }
    
    func testLocateLocatorUsesTotalProgression() {
        let service = makeService(readingOrder: [
            Link(href: "l1", type: "audio/mpeg", duration: 100),
            Link(href: "l2", type: "audio/mpeg", duration: 100)
        ])
    
        XCTAssertEqual(
            service.locate(Locator(href: "wrong", type: "audio/mpeg", locations: .init(totalProgression: 0.49))),
            Locator(href: "l1", type: "audio/mpeg", locations: .init(
                fragments: ["t=98"],
                progression: 98/100.0,
                totalProgression: 0.49
            ))
        )
    
        XCTAssertEqual(
            service.locate(Locator(href: "wrong", type: "audio/mpeg", locations: .init(totalProgression: 0.5))),
            Locator(href: "l2", type: "audio/mpeg", locations: .init(
                fragments: ["t=0"],
                progression: 0,
                totalProgression: 0.5
            ))
        )
    
        XCTAssertEqual(
            service.locate(Locator(href: "wrong", type: "audio/mpeg", locations: .init(totalProgression: 0.51))),
            Locator(href: "l2", type: "audio/mpeg", locations: .init(
                fragments: ["t=2"],
                progression: 0.02,
                totalProgression: 0.51
            ))
        )
    }
    
    func testLocateLocatorUsingTotalProgressionKeepsTitleAndText() {
        let service = makeService(readingOrder: [
            Link(href: "l1", type: "audio/mpeg", duration: 100),
            Link(href: "l2", type: "audio/mpeg", duration: 100)
        ])
    
        XCTAssertEqual(
            service.locate(
                Locator(
                    href: "wrong",
                    type: "wrong-type",
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
            ),
            Locator(
                href: "l1",
                type: "audio/mpeg",
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
    
    func testLocateProgression() {
        let service = makeService(readingOrder: [
            Link(href: "l1", type: "audio/mpeg", duration: 100),
            Link(href: "l2", type: "audio/mpeg", duration: 100)
        ])
    
        XCTAssertEqual(
            service.locate(progression: 0),
            Locator(href: "l1", type: "audio/mpeg", locations: .init(
                fragments: ["t=0"],
                progression: 0,
                totalProgression: 0
            ))
        )
    
        XCTAssertEqual(
            service.locate(progression: 0.49),
            Locator(href: "l1", type: "audio/mpeg", locations: .init(
                fragments: ["t=98"],
                progression: 98/100.0,
                totalProgression: 0.49
            ))
        )
    
        XCTAssertEqual(
            service.locate(progression: 0.5),
            Locator(href: "l2", type: "audio/mpeg", locations: .init(
                fragments: ["t=0"],
                progression: 0,
                totalProgression: 0.5
            ))
        )
    
        XCTAssertEqual(
            service.locate(progression: 0.51),
            Locator(href: "l2", type: "audio/mpeg", locations: .init(
                fragments: ["t=2"],
                progression: 0.02,
                totalProgression: 0.51
            ))
        )
    
        XCTAssertEqual(
            service.locate(progression: 1),
            Locator(href: "l2", type: "audio/mpeg", locations: .init(
                fragments: ["t=100"],
                progression: 1,
                totalProgression: 1
            ))
        )
    }
    
    func testLocateInvalidProgression() {
        let service = makeService(readingOrder: [
            Link(href: "l1", type: "audio/mpeg", duration: 100),
            Link(href: "l2", type: "audio/mpeg", duration: 100)
        ])
    
        XCTAssertNil(service.locate(progression: -0.5))
        XCTAssertNil(service.locate(progression: 1.5))
    }
    
    private func makeService(readingOrder: [Link]) -> AudioLocatorService {
        AudioLocatorService(
            publication: _Strong(Publication(
                manifest: Manifest(metadata: Metadata(title: ""), readingOrder: readingOrder)
            ))
        )
    }
    
}
