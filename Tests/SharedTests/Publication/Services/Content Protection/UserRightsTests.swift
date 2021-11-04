//
//  UserRightsTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 09/08/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

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
