//
//  URLTests.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 12/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

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
