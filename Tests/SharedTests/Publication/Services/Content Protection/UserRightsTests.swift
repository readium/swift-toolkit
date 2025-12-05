//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class UserRightsTests: XCTestCase {
    func testUnrestricted() async {
        let rights = UnrestrictedUserRights()

        let r1 = await rights.canCopy(text: "1")
        XCTAssertTrue(r1)

        let r2 = await rights.copy(text: "1")
        XCTAssertTrue(r2)

        let r3 = await rights.canPrint(pageCount: 1)
        XCTAssertTrue(r3)

        let r4 = await rights.print(pageCount: 1)
        XCTAssertTrue(r4)
    }

    func testAllRestricted() async {
        let rights = AllRestrictedUserRights()

        let r1 = await rights.canCopy(text: "1")
        XCTAssertFalse(r1)

        let r2 = await rights.copy(text: "1")
        XCTAssertFalse(r2)

        let r3 = await rights.canPrint(pageCount: 1)
        XCTAssertFalse(r3)

        let r4 = await rights.print(pageCount: 1)
        XCTAssertFalse(r4)
    }
}
