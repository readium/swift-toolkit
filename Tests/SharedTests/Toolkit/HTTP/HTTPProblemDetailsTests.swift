//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class HTTPProblemDetailsTests: XCTestCase {
    /// Parses a minimal Problem Details JSON.
    func testParseMinimalJSON() throws {
        let json = """
            {"title": "You do not have enough credit."}
        """.data(using: .utf8)!

        XCTAssertEqual(try (HTTPProblemDetails(data: json)).title, "You do not have enough credit.")
    }

    /// Parses a full Problem Details JSON.
    func testParseFullJSON() throws {
        let json = """
            {
                "type": "https://example.net/validation-error",
                "title": "Your request parameters didn't validate.",
                "status": 400,
                "invalid-params": [
                    {
                        "name": "age",
                        "reason": "must be a positive integer"
                    },
                    {
                        "name": "color",
                        "reason": "must be 'green', 'red' or 'blue'"
                    }
                ]
            }
        """.data(using: .utf8)!

        XCTAssertEqual(
            try HTTPProblemDetails(data: json),
            HTTPProblemDetails(
                title: "Your request parameters didn't validate.",
                type: "https://example.net/validation-error",
                status: 400
            )
        )
    }
}
