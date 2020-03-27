//
//  EPUBLayoutTests.swift
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

class EPUBLayoutTests: XCTestCase {

    func testParseLayout() {
        XCTAssertEqual(EPUBLayout(rawValue: "fixed"), .fixed)
        XCTAssertEqual(EPUBLayout(rawValue: "reflowable"), .reflowable)
        XCTAssertNil(EPUBLayout(rawValue: "foobar"))
    }

    func testGetLayoutValue() {
        XCTAssertEqual("fixed", EPUBLayout.fixed.rawValue)
        XCTAssertEqual("reflowable", EPUBLayout.reflowable.rawValue)
    }

}
