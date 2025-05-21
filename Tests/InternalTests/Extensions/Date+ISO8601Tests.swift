//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumInternal
import XCTest

class DateISO8601Tests: XCTestCase {
    func testDateFromISO8601() {
        XCTAssertEqual("2019".dateFromISO8601?.timeIntervalSince1970, 1_546_300_800)
        XCTAssertEqual("2019-03".dateFromISO8601?.timeIntervalSince1970, 1_551_398_400)
        XCTAssertEqual("2019-03-12".dateFromISO8601?.timeIntervalSince1970, 1_552_348_800)
        XCTAssertEqual("2019-03-12T07:58:31".dateFromISO8601?.timeIntervalSince1970, 1_552_377_511)
        XCTAssertEqual("2019-03-12T07:58:31Z".dateFromISO8601?.timeIntervalSince1970, 1_552_377_511)
    }
}
