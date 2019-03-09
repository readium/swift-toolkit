//
//  WPEncryptedTests.swift
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

class WPEncryptedTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? WPEncrypted(json: ["algorithm": "http://algo"]),
            WPEncrypted(algorithm: "http://algo")
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? WPEncrypted(json: [
                "algorithm": "http://algo",
                "compression": "gzip",
                "original-length": 42099,
                "profile": "http://profile",
                "scheme": "http://scheme"
            ]),
            WPEncrypted(
                algorithm: "http://algo",
                compression: "gzip",
                originalLength: 42099,
                profile: "http://profile",
                scheme: "http://scheme"
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try WPEncrypted(json: ""))
    }
    
    func testParseJSONRequiresAlgorithm() {
        XCTAssertThrowsError(try WPEncrypted(json: [
            "compression": "gzip"
        ]))
    }
    
    func testParseAllowsNil() {
        XCTAssertNil(try WPEncrypted(json: nil))
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(
            WPEncrypted(algorithm: "http://algo").json,
            ["algorithm": "http://algo"]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            WPEncrypted(
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
