//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

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
                "scheme": "http://scheme",
            ] as [String: Any]),
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
            "compression": "gzip",
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
            ] as [String: Any]),
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
                "scheme": "http://scheme",
            ] as [String: Any]
        )
    }
}
