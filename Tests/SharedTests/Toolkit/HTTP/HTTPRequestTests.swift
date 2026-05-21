//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

struct HTTPRequestTests {
    private let url = HTTPURL(string: "http://example.com")!

    @Test func setRange() {
        var request = HTTPRequest(url: url)

        request.setRange(0 ..< 100)
        #expect(request.headers["Range"] == "bytes=0-99")

        request.setRange(100 ..< 200)
        #expect(request.headers["Range"] == "bytes=100-199")
    }

    @Test func setRangeUntilEnd() {
        var request = HTTPRequest(url: url)

        request.setRange(100...)
        #expect(request.headers["Range"] == "bytes=100-")
    }

    @Test func setPOSTForm() {
        var request = HTTPRequest(url: url)
        request.setPOSTForm([
            "field1": "value1",
            "field2": "value with spaces",
            "field3": "special&*characters",
            "field4": nil,
        ])

        #expect(request.method == .post)
        #expect(request.headers["Content-Type"] == "application/x-www-form-urlencoded")

        if case let .data(data) = request.body, let bodyString = String(data: data, encoding: .utf8) {
            let parts = bodyString.split(separator: "&")
            #expect(parts.contains("field1=value1"))
            #expect(parts.contains("field2=value+with+spaces"))
            #expect(parts.contains("field3=special%26*characters"))
            #expect(parts.contains("field4="))
            #expect(parts.count == 4)
        } else {
            Issue.record("Expected data body")
        }
    }
}
