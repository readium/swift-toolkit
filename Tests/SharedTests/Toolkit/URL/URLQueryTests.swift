//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

enum URLQueryTests {
    struct Parsing {
        @Test("URL without query returns nil")
        func parseEmptyQuery() throws {
            let query = try URLQuery(url: #require(URL(string: "foo")))
            #expect(query == nil)
        }

        @Test("first(named:) returns the first matching parameter value")
        func getFirstQueryParameterNamedX() throws {
            let query = try #require(URLQuery(
                url: URL(string: "foo?query=param&fruit=banana&query=other&empty")!
            ))
            #expect(query.first(named: "query") == "param")
            #expect(query.first(named: "fruit") == "banana")
            #expect(query.first(named: "empty") == nil)
            #expect(query.first(named: "not-found") == nil)
        }

        @Test("all(named:) returns all matching parameter values")
        func getAllQueryParametersNamedX() throws {
            let query = try #require(URLQuery(
                url: URL(string: "foo?query=param&fruit=banana&query=other&empty")!
            ))
            #expect(query.all(named: "query") == ["param", "other"])
            #expect(query.all(named: "fruit") == ["banana"])
            #expect(query.all(named: "empty") == [])
            #expect(query.all(named: "not-found") == [])
        }

        @Test("parameter values are percent-decoded")
        func queryParameterArePercentDecoded() throws {
            let query = try #require(URLQuery(
                url: URL(string: "foo?query=hello%20world")!
            ))
            #expect(query.first(named: "query") == "hello world")
        }
    }
}
