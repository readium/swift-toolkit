//
//  ReadingProgressionTests.swift
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

class ReadingProgressionTests: XCTestCase {
    
    func testParseReadingProgression() {
        XCTAssertEqual(ReadingProgression(rawValue: "ltr"), ReadingProgression.ltr)
        XCTAssertEqual(ReadingProgression(rawValue: "rtl"), ReadingProgression.rtl)
        XCTAssertEqual(ReadingProgression(rawValue: "ttb"), ReadingProgression.ttb)
        XCTAssertEqual(ReadingProgression(rawValue: "btt"), ReadingProgression.btt)
        XCTAssertEqual(ReadingProgression(rawValue: "auto"), ReadingProgression.auto)
    }
    
    func testGetReadingProgressionValue() {
        XCTAssertEqual(ReadingProgression.ltr.rawValue, "ltr")
        XCTAssertEqual(ReadingProgression.rtl.rawValue, "rtl")
        XCTAssertEqual(ReadingProgression.ttb.rawValue, "ttb")
        XCTAssertEqual(ReadingProgression.btt.rawValue, "btt")
        XCTAssertEqual(ReadingProgression.auto.rawValue, "auto")
    }

}
