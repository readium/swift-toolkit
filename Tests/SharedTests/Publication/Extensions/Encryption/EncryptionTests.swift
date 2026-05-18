//
//  Copyright 2026 Readium Foundation. All rights reserved.
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
            ] as JSONValue),
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
        XCTAssertNil(try Encryption(json: nil as JSONValue?))
    }

    /// `original-length` used to be the key for `originalLength`, so we parse it for backward
    /// compatibility.
    func testParseOldOriginalLength() {
        XCTAssertEqual(
            try? Encryption(json: [
                "algorithm": "http://algo",
                "original-length": 42099,
            ] as JSONValue),
            Encryption(algorithm: "http://algo", originalLength: 42099)
        )
    }

    func testGetMinimalJSON() {
        XCTAssertEqual(
            Encryption(algorithm: "http://algo").jsonObject,
            ["algorithm": "http://algo"]
        )
    }

    func testGetFullJSON() {
        XCTAssertEqual(
            Encryption(
                algorithm: "http://algo",
                compression: "gzip",
                originalLength: 42099,
                profile: "http://profile",
                scheme: "http://scheme"
            ).jsonObject,
            [
                "algorithm": "http://algo",
                "compression": "gzip",
                "originalLength": 42099,
                "profile": "http://profile",
                "scheme": "http://scheme",
            ] as [String: JSONValue]
        )
    }
}
