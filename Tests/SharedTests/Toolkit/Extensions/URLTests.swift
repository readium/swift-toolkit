//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import R2Shared
import XCTest

class URLTests: XCTestCase {
    func testIsParentOfChildIsTrue() {
        let folder = URL(fileURLWithPath: "/root/folder")
        XCTAssertTrue(folder.isParentOf(URL(fileURLWithPath: "/root/folder/child")))
    }

    func testIsParentOfGrandChildIsTrue() {
        let folder = URL(fileURLWithPath: "/root/folder")
        XCTAssertTrue(folder.isParentOf(URL(fileURLWithPath: "/root/folder/child/grand-child")))
    }

    func testIsParentOfItselfIsTrue() {
        let folder = URL(fileURLWithPath: "/root/folder")
        XCTAssertTrue(folder.isParentOf(URL(fileURLWithPath: "/root/folder")))
    }

    func testIsParentOfParentIsFalse() {
        let folder = URL(fileURLWithPath: "/root/folder")
        XCTAssertFalse(folder.isParentOf(URL(fileURLWithPath: "/root")))
    }

    func testIsParentOfSiblingIsFalse() {
        let folder = URL(fileURLWithPath: "/root/folder")
        XCTAssertFalse(folder.isParentOf(URL(fileURLWithPath: "/root/sibling")))
    }

    func testIsParentOfSiblingWithSamePrefixIsFalse() {
        let folder = URL(fileURLWithPath: "/root/folder")
        XCTAssertFalse(folder.isParentOf(URL(fileURLWithPath: "/root/folder-sibling/child")))
    }

    func testIsParentOfOutside() {
        let folder = URL(fileURLWithPath: "/root/folder")
        XCTAssertTrue(folder.isParentOf(URL(fileURLWithPath: "/root/folder/child/../other-child")))
        XCTAssertFalse(folder.isParentOf(URL(fileURLWithPath: "/root/folder/child/../../sibling")))
        XCTAssertFalse(folder.isParentOf(URL(fileURLWithPath: "/root/folder/child/../../folder-sibling/child")))
    }

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
