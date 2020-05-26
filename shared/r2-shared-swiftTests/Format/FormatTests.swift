//
//  FormatTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 10/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class FormatTests: XCTestCase {

    func testEqualsChecksOnlyMediaType() {
        XCTAssertEqual(
            Format(name: "A", mediaType: MediaType.png, fileExtension: "a"),
            Format(name: "B", mediaType: MediaType.png, fileExtension: "b")
        )
        XCTAssertNotEqual(
            Format(name: "A", mediaType: MediaType.png, fileExtension: "a"),
            Format(name: "A", mediaType: MediaType.jpeg, fileExtension: "a")
        )
    }

}
