//
//  Metadata+PresentationTests.swift
//  r2-shared-swift
//
//  Created by Mickaël on 24/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class MetadataPresentationTests: XCTestCase {

    func testGetPresentationWhenAvailable() {
        XCTAssertEqual(
            Metadata(
                title: "Title",
                otherMetadata: [
                    "presentation": [
                        "continuous": false,
                        "orientation": "landscape"
                    ]
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
