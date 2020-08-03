//
//  URLTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 03/08/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class URLTests: XCTestCase {

    func testAddingSchemeIfMissing() {
        XCTAssertEqual(
            URL(string: "//www.google.com/path")!.addingSchemeIfMissing("test"),
            URL(string: "test://www.google.com/path")!
        )
        XCTAssertEqual(
            URL(string: "http://www.google.com/path")!.addingSchemeIfMissing("test"),
            URL(string: "http://www.google.com/path")!
        )
    }

}
