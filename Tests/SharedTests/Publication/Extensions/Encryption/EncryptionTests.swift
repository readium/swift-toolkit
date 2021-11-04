//
//  EncryptionTests.swift
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

class EncryptionTests: XCTestCase {
    
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Encryption(json: ["algorithm": "http://algo"]),
            Encryption(algorithm: "http://algo")
        )
    }
    
    func testParseFullJSON() {
        XCTAssertEqual(
            try? Encryption(json: [
                "algorithm": "http://algo",
                "compression": "gzip",
                "originalLength": 42099,
                "profile": "http://profile",
                "scheme": "http://scheme"
            ]),
            Encryption(
                algorithm: "http://algo",
                compression: "gzip",
                originalLength: 42099,
                profile: "http://profile",
                scheme: "http://scheme"
            )
        )
    }
    
    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Encryption(json: ""))
    }
    
    func testParseJSONRequiresAlgorithm() {
        XCTAssertThrowsError(try Encryption(json: [
            "compression": "gzip"
        ]))
    }
    
    func testParseAllowsNil() {
        XCTAssertNil(try Encryption(json: nil))
    }
    
    /// `original-length` used to be the key for `originalLength`, so we parse it for backward
    /// compatibility.
    func testParseOldOriginalLength() {
        XCTAssertEqual(
            try? Encryption(json: [
                "algorithm": "http://algo",
                "original-length": 42099,
            ]),
            Encryption(algorithm: "http://algo", originalLength: 42099)
        )
    }
    
    func testGetMinimalJSON() {
        AssertJSONEqual(
            Encryption(algorithm: "http://algo").json,
            ["algorithm": "http://algo"]
        )
    }
    
    func testGetFullJSON() {
        AssertJSONEqual(
            Encryption(
                algorithm: "http://algo",
                compression: "gzip",
                originalLength: 42099,
                profile: "http://profile",
                scheme: "http://scheme"
            ).json,
            [
                "algorithm": "http://algo",
                "compression": "gzip",
                "originalLength": 42099,
                "profile": "http://profile",
                "scheme": "http://scheme"
            ]
        )
    }

}
