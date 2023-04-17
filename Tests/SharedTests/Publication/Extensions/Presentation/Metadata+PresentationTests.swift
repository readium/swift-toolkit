//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
import XCTest

class MetadataPresentationTests: XCTestCase {
    func testGetPresentationWhenAvailable() {
        XCTAssertEqual(
            Metadata(
                title: "Title",
                otherMetadata: [
                    "presentation": [
                        "continuous": false,
                        "orientation": "landscape",
                    ] as [String: Any],
                ]
            ).presentation,
            Presentation(continuous: false, orientation: .landscape)
        )
    }

    func testGetPresentationWhenMissing() {
        XCTAssertEqual(
            Metadata(title: "Title").presentation,
            Presentation()
        )
    }
}
