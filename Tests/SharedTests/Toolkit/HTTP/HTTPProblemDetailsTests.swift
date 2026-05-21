//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

struct HTTPProblemDetailsTests {
    /// Parses a minimal Problem Details JSON.
    @Test func parseMinimalJSON() throws {
        let json = """
            {"title": "You do not have enough credit."}
        """.data(using: .utf8)!

        let details = try HTTPProblemDetails(data: json)
        #expect(details.title == "You do not have enough credit.")
    }

    /// Parses a full Problem Details JSON.
    @Test func parseFullJSON() throws {
        let json = """
            {
                "type": "https://example.net/validation-error",
                "title": "Your request parameters didn't validate.",
                "status": 400,
                "detail": "Age must be a positive integer.",
                "instance": "https://example.net/validation-error/123",
                "invalid-params": [
                    {
                        "name": "age",
                        "reason": "must be a positive integer"
                    }
                ]
            }
        """.data(using: .utf8)!

        let details = try HTTPProblemDetails(data: json)
        #expect(details.title == "Your request parameters didn't validate.")
        #expect(details.type == "https://example.net/validation-error")
        #expect(details.status == 400)
        #expect(details.detail == "Age must be a positive integer.")
        #expect(details.instance == "https://example.net/validation-error/123")
    }

    @Test func parseInvalidJSON() {
        let json = """
            {"not-a-title": "Missing title"}
        """.data(using: .utf8)!

        #expect(throws: HTTPProblemDetails.Error.self) {
            try HTTPProblemDetails(data: json)
        }
    }

    @Test func extractFromHTTPError() throws {
        let json = """
            {"title": "Forbidden action"}
        """.data(using: .utf8)!

        let response = HTTPErrorResponse(
            status: .forbidden,
            body: json,
            mediaType: .problemDetails,
            headers: ["Content-Type": "application/problem+json"]
        )

        let error = HTTPError.errorResponse(response)
        let details = try error.problemDetails()

        #expect(details?.title == "Forbidden action")
    }
}
