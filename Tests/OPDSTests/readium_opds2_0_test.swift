//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import XCTest

@testable import ReadiumOPDS

class readium_opds2_0_test: XCTestCase {
    var feed: Feed?

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        guard let fileURL = Bundle.module.url(forResource: "Samples/opds_2_0", withExtension: "json") else {
            XCTFail("Unable to locate test file")
            return
        }

        do {
            let opdsData = try Data(contentsOf: fileURL)
            feed = try OPDS2Parser.parse(jsonData: opdsData, url: URL(string: "http://test.com")!, response: HTTPURLResponse()).feed
            XCTAssert(feed != nil)
        } catch {
            XCTFail(error.localizedDescription)
        }

        continueAfterFailure = true
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testMetadata() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssert(feed?.metadata.numberOfItem == 5)
    }
}
