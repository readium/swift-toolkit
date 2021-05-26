//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest
@testable import R2Shared

class DateISO8601Tests: XCTestCase {

    func testDateFromISO8601() {
        XCTAssertEqual("2019".dateFromISO8601?.timeIntervalSince1970, 1546300800)
        XCTAssertEqual("2019-03".dateFromISO8601?.timeIntervalSince1970, 1551398400)
        XCTAssertEqual("2019-03-12".dateFromISO8601?.timeIntervalSince1970, 1552348800)
        XCTAssertEqual("2019-03-12T07:58:31".dateFromISO8601?.timeIntervalSince1970, 1552377511)
        XCTAssertEqual("2019-03-12T07:58:31Z".dateFromISO8601?.timeIntervalSince1970, 1552377511)
    }

}
