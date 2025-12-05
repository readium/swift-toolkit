//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import XCTest

class URLQueryTests: XCTestCase {
    func testParseEmptyQuery() throws {
        let query = URLQuery(url: URL(string: "foo")!)
        XCTAssertNil(query)
    }

    func testGetFirstQueryParameterNamedX() throws {
        let query = try XCTUnwrap(URLQuery(
            url: URL(string: "foo?query=param&fruit=banana&query=other&empty")!
        ))

        XCTAssertEqual(query.first(named: "query"), "param")
        XCTAssertEqual(query.first(named: "fruit"), "banana")
        XCTAssertNil(query.first(named: "empty"))
        XCTAssertNil(query.first(named: "not-found"))
    }

    func testGetAllQueryParametersNamedX() throws {
        let query = try XCTUnwrap(URLQuery(
            url: URL(string: "foo?query=param&fruit=banana&query=other&empty")!
        ))

        XCTAssertEqual(query.all(named: "query"), ["param", "other"])
        XCTAssertEqual(query.all(named: "fruit"), ["banana"])
        XCTAssertEqual(query.all(named: "empty"), [])
        XCTAssertEqual(query.all(named: "not-found"), [])
    }

    func testQueryParameterArePercentDecoded() throws {
        let query = try XCTUnwrap(URLQuery(
            url: URL(string: "foo?query=hello%20world")!
        ))
        XCTAssertEqual(query.first(named: "query"), "hello world")
    }
}
