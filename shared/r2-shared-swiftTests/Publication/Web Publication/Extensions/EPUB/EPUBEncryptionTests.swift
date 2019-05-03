//
//  EPUBEncryptionTests.swift
//  r2-shared-swiftTests
//
//  Created by Mickaël Menu on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class EPUBEncryptionTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? EPUBEncryption(json: ["algorithm": "http://algo"]),
            EPUBEncryption(algorithm: "http://algo")
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? EPUBEncryption(json: [
                "algorithm": "http://algo",
                "compression": "gzip",
                "original-length": 42099,
                "profile": "http://profile",
                "scheme": "http://scheme"
            ]),
            EPUBEncryption(
                algorithm: "http://algo",
                compression: "gzip",
                originalLength: 42099,
                profile: "http://profile",
                scheme: "http://scheme"
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try EPUBEncryption(json: ""))
    }
    
    func testParseJSONRequiresAlgorithm() {
        XCTAssertThrowsError(try EPUBEncryption(json: [
            "compression": "gzip"
        ]))
    }
    
    func testParseAllowsNil() {
        XCTAssertNil(try EPUBEncryption(json: nil))
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(
            EPUBEncryption(algorithm: "http://algo").json,
            ["algorithm": "http://algo"]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            EPUBEncryption(
                algorithm: "http://algo",
                compression: "gzip",
                originalLength: 42099,
                profile: "http://profile",
                scheme: "http://scheme"
            ).json,
            [
                "algorithm": "http://algo",
                "compression": "gzip",
                "original-length": 42099,
                "profile": "http://profile",
                "scheme": "http://scheme"
            ]
        )
    }

}
