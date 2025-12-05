//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

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
