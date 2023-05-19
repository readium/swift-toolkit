//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
import XCTest

class UserRightsTests: XCTestCase {
    func testUnrestricted() {
        let rights = UnrestrictedUserRights()

        XCTAssertTrue(rights.canCopy)
        XCTAssertTrue(rights.canCopy(text: "1"))
        XCTAssertTrue(rights.copy(text: "1"))
        XCTAssertTrue(rights.canPrint)
        XCTAssertTrue(rights.canPrint(pageCount: 1))
        XCTAssertTrue(rights.print(pageCount: 1))
    }

    func testAllRestricted() {
        let rights = AllRestrictedUserRights()

        XCTAssertFalse(rights.canCopy)
        XCTAssertFalse(rights.canCopy(text: "1"))
        XCTAssertFalse(rights.copy(text: "1"))
        XCTAssertFalse(rights.canPrint)
        XCTAssertFalse(rights.canPrint(pageCount: 1))
        XCTAssertFalse(rights.print(pageCount: 1))
    }
}
