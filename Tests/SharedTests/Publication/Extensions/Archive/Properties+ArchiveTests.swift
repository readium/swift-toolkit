//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest
import R2Shared

class PropertiesArchiveTests: XCTestCase {

    func testNoArchive() {
        let sut = Properties()
        XCTAssertNil(sut.archive)
    }

    func testArchive() {
        let sut = Properties(["archive": [
            "entryLength": 8273,
            "isEntryCompressed": true
        ]])

        XCTAssertEqual(sut.archive, Properties.Archive(entryLength: 8273, isEntryCompressed: true))
    }

    func testInvalidArchive() {
        let sut = Properties(["archive": [
            "foo": "bar",
        ]])
        XCTAssertNil(sut.archive)
    }

    func testIncompleteArchive() {
        var sut = Properties(["archive": [
            "entryLength": 8273
        ]])
        XCTAssertNil(sut.archive)

        sut = Properties(["archive": [
            "isEntryCompressed": true
        ]])
        XCTAssertNil(sut.archive)
    }

    func testGetJSON() {
        AssertJSONEqual(
            Properties.Archive(entryLength: 8273, isEntryCompressed: true).json,
            [
                "entryLength": 8273,
                "isEntryCompressed": true
            ]
        )
    }
}
